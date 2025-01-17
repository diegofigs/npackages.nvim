local semver = require("npackages.lib.semver")
local Cond = semver.Cond
local SemVer = semver.SemVer

local M = {}

-- NOTE: Used to index the user configuration, so keys have to be in sync
---@enum DiagnosticCodes
M.DiagnosticCodes = {
	-- error
	SECTION_INVALID = "section_invalid",
	SECTION_DUP = "section_dup",
	PACKAGE_DUP = "package_dup",
	PACKAGE_NOVERS = "package_novers",
	PACKAGE_ERROR_FETCHING = "package_error_fetching",
	PACKAGE_NAME_CASE = "package_name_case",
	VERS_NOMATCH = "vers_nomatch",
	VERS_PRE = "vers_pre",
	-- warning
	VERS_UPGRADE = "vers_upgrade",
	-- hint
	SECTION_DUP_ORIG = "section_dup_orig",
	PACKAGE_DUP_ORIG = "package_dup_orig",
	-- reverse lookup
	section_invalid = "Invalid dependency section",
	section_dup = "Duplicate dependency section",
	package_dup = "Duplicate package",
	package_novers = "Missing version requirement",
	package_error_fetching = "Error fetching package",
	package_name_case = "Incorrect package name casing",
	vers_nomatch = "Requirement doesn't match a version",
	vers_pre = "Requirement only matches a pre-release version\nIf you want to use the pre-release package, it needs to be specified explicitly",
	vers_upgrade = "Upgrade available",
}

---NOTE: Used to index the user configuration, so keys have to be in sync
---@enum MatchKind
M.MatchKind = {
	VERSION = "version",
	YANKED = "yanked",
	PRERELEASE = "prerelease",
	NOMATCH = "nomatch",
	LATEST = "latest",
}

---@enum PackageScope
local PackageScope = {
	VERS = 1,
}

---@param section JsonSection
---@param code DiagnosticCodes
---@param severity lsp.DiagnosticSeverity
---@param data table<string,any>|nil
---@return lsp.Diagnostic
local function to_section_diagnostic(section, code, severity, data)
	---@type lsp.Diagnostic
	return {
		range = section.range,
		message = M.DiagnosticCodes[code],
		code = code,
		severity = severity,
		data = data,
		source = "npackages_ls",
	}
end

---@param pkg JsonPackage
---@param code DiagnosticCodes
---@param severity lsp.DiagnosticSeverity
---@param scope PackageScope|nil
---@param data table<string,any>|nil
---@return lsp.Diagnostic[]
local function to_package_diagnostic(pkg, code, severity, scope, data)
	---@type lsp.Diagnostic
	local d = {
		range = pkg.range,
		message = M.DiagnosticCodes[code],
		code = code,
		severity = severity,
		data = data,
		source = "npackages_ls",
	}

	if not scope then
		return d
	end

	if scope == PackageScope.VERS then
		if pkg.vers then
			d.range = pkg.vers.range
		end
	end

	return d
end

---@param sections JsonSection[]
---@param packages JsonPackage[]
---@return table<string,JsonSection>
---@return table<string,JsonPackage>
---@return lsp.Diagnostic[]
function M.analyze_package_json(sections, packages)
	---@type lsp.Diagnostic[]
	local diagnostics = {}
	---@type table<string,JsonSection>
	local section_set = {}
	---@type table<string,JsonPackage>
	local package_set = {}

	for _, s in ipairs(sections) do
		local key = s.text:gsub("%s+", "")

		if s.invalid then
			table.insert(
				diagnostics,
				to_section_diagnostic(s, M.DiagnosticCodes.SECTION_INVALID, vim.diagnostic.severity.WARN)
			)
		elseif section_set[key] then
			table.insert(
				diagnostics,
				to_section_diagnostic(section_set[key], M.DiagnosticCodes.SECTION_DUP, vim.diagnostic.severity.ERROR)
			)
			table.insert(
				diagnostics,
				to_section_diagnostic(s, M.DiagnosticCodes.SECTION_DUP, vim.diagnostic.severity.ERROR)
			)
		else
			section_set[key] = s
		end
	end

	for _, c in ipairs(packages) do
		local key = c:cache_key()
		if not c.section.invalid then
			if package_set[key] then
				table.insert(
					diagnostics,
					to_package_diagnostic(
						package_set[key],
						M.DiagnosticCodes.PACKAGE_DUP,
						vim.diagnostic.severity.ERROR
					)
				)
				table.insert(
					diagnostics,
					to_package_diagnostic(c, M.DiagnosticCodes.PACKAGE_DUP, vim.diagnostic.severity.ERROR)
				)
			else
				package_set[key] = c
			end
		end
	end

	return section_set, package_set, diagnostics
end

---@param package JsonPackage
---@param api_package PackageMetadata|nil
---@return PackageInfo
---@return lsp.Diagnostic[]
function M.analyze_package_metadata(package, api_package)
	local versions = api_package and api_package.versions
	local newest, newest_pre = M.get_newest(versions, nil)
	newest = newest or newest_pre

	---@type PackageInfo
	local info = {
		range = package.range,
		match_kind = M.MatchKind.NOMATCH,
	}
	local diagnostics = {}

	if package.dep_kind == 1 then
		if api_package then
			if api_package.name ~= package:package() then
				table.insert(
					diagnostics,
					to_package_diagnostic(
						package,
						M.DiagnosticCodes.PACKAGE_NAME_CASE,
						vim.diagnostic.severity.ERROR,
						nil,
						{ crate = package, crate_name = api_package.name }
					)
				)
			end
		end

		if newest then
			if semver.matches_requirements(newest.parsed, package:vers_reqs()) then
				-- version matches, no upgrade available
				info.vers_match = newest
				info.match_kind = M.MatchKind.LATEST

				if package.vers and package.vers.text ~= M.version_text(package, newest.parsed) then
					info.vers_update = newest
				end
			else
				-- version does not match, upgrade available
				local match, match_pre, match_yanked = M.get_newest(versions, package:vers_reqs())
				info.vers_match = match or match_pre or match_yanked
				info.vers_upgrade = newest

				if info.vers_match then
					if package.vers and package.vers.text ~= M.version_text(package, info.vers_match.parsed) then
						info.vers_update = info.vers_match
					end
				end

				table.insert(
					diagnostics,
					to_package_diagnostic(
						package,
						M.DiagnosticCodes.VERS_UPGRADE,
						vim.diagnostic.severity.WARN,
						PackageScope.VERS
					)
				)

				if match then
					-- found a match
					info.match_kind = M.MatchKind.VERSION
				elseif match_pre then
					-- found a pre-release match
					info.match_kind = M.MatchKind.PRERELEASE
					table.insert(
						diagnostics,
						to_package_diagnostic(
							package,
							M.DiagnosticCodes.VERS_PRE,
							vim.diagnostic.severity.ERROR,
							PackageScope.VERS
						)
					)
				else
					-- no match found
					local kind = M.DiagnosticCodes.VERS_NOMATCH
					if not package.vers then
						kind = M.DiagnosticCodes.PACKAGE_NOVERS
					end
					table.insert(
						diagnostics,
						to_package_diagnostic(package, kind, vim.diagnostic.severity.ERROR, PackageScope.VERS)
					)
				end
			end
		else
			table.insert(
				diagnostics,
				to_package_diagnostic(
					package,
					M.DiagnosticCodes.PACKAGE_ERROR_FETCHING,
					vim.diagnostic.severity.ERROR,
					PackageScope.VERS
				)
			)
		end
	end

	return info, diagnostics
end

-- TODO: implement multi-depth dependency analysis
--
---@param package JsonPackage
---@param _version ApiVersion
---@param _deps ApiDependency[]
---@return lsp.Diagnostic[]
function M.analyze_package_deps(package, _version, _deps)
	return {}
end

---@param r Requirement
---@param version SemVer
---@return SemVer
local function replace_existing(r, version)
	if version.pre then
		return version
	else
		return SemVer.new({
			major = version.major,
			minor = r.vers.minor and version.minor or nil,
			patch = r.vers.patch and version.patch or nil,
		})
	end
end

---@param package JsonPackage
---@param version SemVer
---@return string
function M.smart_version_text(package, version)
	if #package:vers_reqs() == 0 then
		return version:display()
	end

	local pos = 1
	local text = ""
	for _, r in ipairs(package:vers_reqs()) do
		if r.cond == Cond.EQ then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.WL then
			if version.pre then
				text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. version:display()
			else
				local v = SemVer.new({
					major = r.vers.major and version.major or nil,
					minor = r.vers.minor and version.minor or nil,
				})
				local before = string.sub(package.vers.text, pos, r.vers_col.s)
				local after = string.sub(package.vers.text, r.vers_col.e + 1, r.cond_col.e)
				text = text .. before .. v:display() .. after
			end
		elseif r.cond == Cond.TL then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.CR then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.BL then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.LT and not semver.matches_requirement(version, r) then
			local v = SemVer.new({
				major = version.major,
				minor = r.vers.minor and version.minor or nil,
				patch = r.vers.patch and version.patch or nil,
			})

			if v.patch then
				v.patch = v.patch + 1
			elseif v.minor then
				v.minor = v.minor + 1
			elseif v.major then
				v.major = v.major + 1
			end

			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.LE and not semver.matches_requirement(version, r) then
			---@type SemVer
			local v

			if version.pre then
				v = version
			else
				v = SemVer.new({ major = version.major })
				if r.vers.minor or version.minor and version.minor > 0 then
					v.minor = version.minor
				end
				if r.vers.patch or version.patch and version.patch > 0 then
					v.minor = version.minor
					v.patch = version.patch
				end
			end

			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.GT and not semver.matches_requirement(version, r) then
			local v = SemVer.new({
				major = r.vers.major and version.major or nil,
				minor = r.vers.minor and version.minor or nil,
				patch = r.vers.patch and version.patch or nil,
			})

			if v.patch then
				v.patch = v.patch - 1
				if v.patch < 0 then
					v.patch = 0
					v.minor = v.minor - 1
				end
			elseif v.minor then
				v.minor = v.minor - 1
				if v.minor < 0 then
					v.minor = 0
					v.major = v.major - 1
				end
			elseif v.major then
				v.major = v.major - 1
				if v.major < 0 then
					v.major = 0
				end
			end

			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.GE then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		else
			text = text .. string.sub(package.vers.text, pos, r.vers_col.e)
		end

		pos = math.max(r.cond_col.e + 1, r.vers_col.e + 1)
	end
	text = text .. string.sub(package.vers.text, pos)

	return text
end

---@param package JsonPackage
---@param version SemVer
---@param alt boolean|nil
---@return string
function M.version_text(package, version, alt)
	local smart = alt ~= true
	if smart then
		return M.smart_version_text(package, version)
	else
		return version:display()
	end
end

---@param versions ApiVersion[]|nil
---@param reqs Requirement[]|nil
---@return ApiVersion|nil
---@return ApiVersion|nil
---@return ApiVersion|nil
function M.get_newest(versions, reqs)
	if not versions or not next(versions) then
		return nil
	end

	local allow_pre = reqs and semver.allows_pre(reqs) or false

	---@type ApiVersion|nil, ApiVersion|nil
	local newest_pre, newest

	for _, v in ipairs(versions) do
		if not reqs or semver.matches_requirements(v.parsed, reqs) then
			-- if not v.yanked then
			if allow_pre or not v.parsed.pre then
				newest = v
				break
			else
				newest_pre = newest_pre or v
			end
			-- else
			-- 	newest_yanked = newest_yanked or v
			-- end
		end
	end

	return newest, newest_pre
end

return M
