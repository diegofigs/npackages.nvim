local edit = require("npackages.edit")
local semver = require("npackages.semver")
local state = require("npackages.state")
local json = require("npackages.json")
local DepKind = json.DepKind
local JsonSectionKind = json.JsonSectionKind
local types = require("npackages.types")
local NpackagesDiagnostic = types.NpackagesDiagnostic
local NpackagesDiagnosticKind = types.NpackagesDiagnosticKind
local MatchKind = types.MatchKind
local util = require("npackages.util")

local M = {}

---@enum SectionScope
local SectionScope = {
	HEADER = 1,
}

---@enum PackageScope
local PackageScope = {
	VERS = 1,
	DEF = 2,
	FEAT = 3,
}

---@param section JsonSection
---@param kind NpackagesDiagnosticKind
---@param severity integer
---@param scope SectionScope|nil
---@param data table<string,any>|nil
---@return NpackagesDiagnostic
local function section_diagnostic(section, kind, severity, scope, data)
	local d = NpackagesDiagnostic.new({
		lnum = section.lines.s,
		end_lnum = section.lines.e - 1,
		col = 0,
		end_col = 999,
		severity = severity,
		kind = kind,
		data = data,
	})

	if scope == SectionScope.HEADER then
		d.end_lnum = d.lnum + 1
	end

	return d
end

---@param crate JsonPackage
---@param kind NpackagesDiagnosticKind
---@param severity integer
---@param scope PackageScope|nil
---@param data table<string,any>|nil
---@return NpackagesDiagnostic
local function crate_diagnostic(crate, kind, severity, scope, data)
	local d = NpackagesDiagnostic.new({
		lnum = crate.lines.s,
		end_lnum = crate.lines.e - 1,
		col = 0,
		end_col = 999,
		severity = severity,
		kind = kind,
		data = data,
	})

	if not scope then
		return d
	end

	if scope == PackageScope.VERS then
		if crate.vers then
			d.lnum = crate.vers.line
			d.end_lnum = crate.vers.line
			d.col = crate.vers.col.s
			d.end_col = crate.vers.col.e
		end
	elseif scope == PackageScope.DEF then
		if crate.def then
			d.lnum = crate.def.line
			d.end_lnum = crate.def.line
			d.col = crate.def.col.s
			d.end_col = crate.def.col.e
		end
	elseif scope == PackageScope.FEAT then
		if crate.feat then
			d.lnum = crate.feat.line
			d.end_lnum = crate.feat.line
			d.col = crate.feat.col.s
			d.end_col = crate.feat.col.e
		end
	end

	return d
end

---@param crate JsonPackage
---@param feat TomlFeature
---@param kind NpackagesDiagnosticKind
---@param severity integer
---@param data table<string,any>|nil
---@return NpackagesDiagnostic
local function feat_diagnostic(crate, feat, kind, severity, data)
	return NpackagesDiagnostic.new({
		lnum = crate.feat.line,
		end_lnum = crate.feat.line,
		col = crate.feat.col.s + feat.col.s,
		end_col = crate.feat.col.s + feat.col.e,
		severity = severity,
		kind = kind,
		data = data,
	})
end

---@param sections JsonSection[]
---@param packages JsonPackage[]
---@return table<string,JsonPackage>
---@return NpackagesDiagnostic[]
function M.process_packages(sections, packages)
	---@type NpackagesDiagnostic[]
	local diagnostics = {}
	---@type table<string,JsonSection>
	local s_cache = {}
	---@type table<string,JsonPackage>
	local cache = {}

	for _, s in ipairs(sections) do
		local key = s.text:gsub("%s+", "")

		if s.workspace and s.kind ~= JsonSectionKind.DEFAULT then
			table.insert(
				diagnostics,
				section_diagnostic(
					s,
					NpackagesDiagnosticKind.WORKSPACE_SECTION_NOT_DEFAULT,
					vim.diagnostic.severity.WARN
				)
			)
		elseif s.workspace and s.target ~= nil then
			table.insert(
				diagnostics,
				section_diagnostic(
					s,
					NpackagesDiagnosticKind.WORKSPACE_SECTION_HAS_TARGET,
					vim.diagnostic.severity.ERROR
				)
			)
		elseif s.invalid then
			table.insert(
				diagnostics,
				section_diagnostic(s, NpackagesDiagnosticKind.SECTION_INVALID, vim.diagnostic.severity.WARN)
			)
		elseif s_cache[key] then
			table.insert(
				diagnostics,
				section_diagnostic(
					s_cache[key],
					NpackagesDiagnosticKind.SECTION_DUP_ORIG,
					vim.diagnostic.severity.HINT,
					SectionScope.HEADER,
					{ lines = s_cache[key].lines }
				)
			)
			table.insert(
				diagnostics,
				section_diagnostic(s, NpackagesDiagnosticKind.SECTION_DUP, vim.diagnostic.severity.ERROR)
			)
		else
			s_cache[key] = s
		end
	end

	for _, c in ipairs(packages) do
		local key = c:cache_key()
		if c.section.invalid then
			goto continue
		end

		if cache[key] then
			table.insert(
				diagnostics,
				crate_diagnostic(cache[key], NpackagesDiagnosticKind.CRATE_DUP_ORIG, vim.diagnostic.severity.HINT)
			)
			table.insert(
				diagnostics,
				crate_diagnostic(c, NpackagesDiagnosticKind.CRATE_DUP, vim.diagnostic.severity.ERROR)
			)
		else
			cache[key] = c

			if c.def then
				if c.def.text ~= "false" and c.def.text ~= "true" then
					table.insert(
						diagnostics,
						crate_diagnostic(
							c,
							NpackagesDiagnosticKind.DEF_INVALID,
							vim.diagnostic.severity.ERROR,
							PackageScope.DEF
						)
					)
				end
			end
		end

		::continue::
	end

	return cache, diagnostics
end

---@param package JsonPackage
---@param api_package ApiPackage|nil
---@return PackageInfo
---@return NpackagesDiagnostic[]
function M.process_api_package(package, api_package)
	local versions = api_package and api_package.versions
	local newest, newest_pre, newest_yanked = util.get_newest(versions, nil)
	newest = newest or newest_pre or newest_yanked

	---@type PackageInfo
	local info = {
		lines = package.lines,
		vers_line = package.vers and package.vers.line or package.lines.s,
		match_kind = MatchKind.NOMATCH,
	}
	local diagnostics = {}

	if package.dep_kind == DepKind.REGISTRY then
		if api_package then
			if api_package.name ~= package:package() then
				table.insert(
					diagnostics,
					crate_diagnostic(
						package,
						NpackagesDiagnosticKind.CRATE_NAME_CASE,
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
				info.match_kind = MatchKind.VERSION

				if package.vers and package.vers.text ~= edit.version_text(package, newest.parsed) then
					info.vers_update = newest
				end
			else
				-- version does not match, upgrade available
				local match, match_pre, match_yanked = util.get_newest(versions, package:vers_reqs())
				info.vers_match = match or match_pre or match_yanked
				info.vers_upgrade = newest

				if info.vers_match then
					if package.vers and package.vers.text ~= edit.version_text(package, info.vers_match.parsed) then
						info.vers_update = info.vers_match
					end
				end

				if state.cfg.enable_update_available_warning then
					table.insert(
						diagnostics,
						crate_diagnostic(
							package,
							NpackagesDiagnosticKind.VERS_UPGRADE,
							vim.diagnostic.severity.WARN,
							PackageScope.VERS
						)
					)
				end

				if match then
					-- found a match
					info.match_kind = MatchKind.VERSION
				elseif match_pre then
					-- found a pre-release match
					info.match_kind = MatchKind.PRERELEASE
					table.insert(
						diagnostics,
						crate_diagnostic(
							package,
							NpackagesDiagnosticKind.VERS_PRE,
							vim.diagnostic.severity.ERROR,
							PackageScope.VERS
						)
					)
				elseif match_yanked then
					-- found a yanked match
					info.match_kind = MatchKind.YANKED
					table.insert(
						diagnostics,
						crate_diagnostic(
							package,
							NpackagesDiagnosticKind.VERS_YANKED,
							vim.diagnostic.severity.ERROR,
							PackageScope.VERS
						)
					)
				else
					-- no match found
					local kind = NpackagesDiagnosticKind.VERS_NOMATCH
					if not package.vers then
						kind = NpackagesDiagnosticKind.CRATE_NOVERS
					end
					table.insert(
						diagnostics,
						crate_diagnostic(package, kind, vim.diagnostic.severity.ERROR, PackageScope.VERS)
					)
				end
			end
		else
			table.insert(
				diagnostics,
				crate_diagnostic(
					package,
					NpackagesDiagnosticKind.CRATE_ERROR_FETCHING,
					vim.diagnostic.severity.ERROR,
					PackageScope.VERS
				)
			)
		end
	end

	return info, diagnostics
end

---@param package JsonPackage
---@param version ApiVersion
---@param deps ApiDependency[]
---@return NpackagesDiagnostic[]
function M.process_package_deps(package, version, deps)
	if package.path or package.git then
		return {}
	end

	local diagnostics = {}

	local valid_feats = {}
	for _, d in ipairs(deps) do
		if d.opt then
			table.insert(valid_feats, d.name)
		end
	end

	return diagnostics
end

return M
