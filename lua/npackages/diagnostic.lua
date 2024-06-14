local edit = require("npackages.util.edit")
local semver = require("npackages.semver")
local state = require("npackages.state")
local scanner = require("npackages.lsp.scanner")
local DepKind = scanner.DepKind
local util = require("npackages.util")

---@class NpackagesDiagnostic
---@field lnum integer
---@field end_lnum integer
---@field col integer
---@field end_col integer
---@field severity integer
---@field kind NpackagesDiagnosticKind
---@field data table<string,any>|nil
local NpackagesDiagnostic = {}

---@param obj NpackagesDiagnostic
---@return NpackagesDiagnostic
function NpackagesDiagnostic.new(obj)
	return setmetatable(obj, { __index = NpackagesDiagnostic })
end

---@param line integer
---@param col integer
---@return boolean
function NpackagesDiagnostic:contains(line, col)
	return (self.lnum < line or self.lnum == line and self.col <= col)
		and (self.end_lnum > line or self.end_lnum == line and self.end_col > col)
end

local M = {}

---NOTE: Used to index the user configuration, so keys have to be in sync
---@enum NpackagesDiagnosticKind
M.NpackagesDiagnosticKind = {
	-- error
	SECTION_INVALID = "section_invalid",
	SECTION_DUP = "section_dup",
	PACKAGE_DUP = "package_dup",
	PACKAGE_NOVERS = "crate_novers",
	PACKAGE_ERROR_FETCHING = "crate_error_fetching",
	CRATE_NAME_CASE = "crate_name_case",
	VERS_NOMATCH = "vers_nomatch",
	VERS_YANKED = "vers_yanked",
	VERS_PRE = "vers_pre",
	-- warning
	VERS_UPGRADE = "vers_upgrade",
	-- hint
	SECTION_DUP_ORIG = "section_dup_orig",
	PACKAGE_DUP_ORIG = "package_dup_orig",
}

---NOTE: Used to index the user configuration, so keys have to be in sync
---@enum MatchKind
M.MatchKind = {
	VERSION = "version",
	YANKED = "yanked",
	PRERELEASE = "prerelease",
	NOMATCH = "nomatch",
}

---@enum SectionScope
local SectionScope = {
	HEADER = 1,
}

---@enum PackageScope
local PackageScope = {
	VERS = 1,
	DEF = 2,
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
		col = section.name_col.s,
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
local function package_diagnostic(crate, kind, severity, scope, data)
	local d = NpackagesDiagnostic.new({
		lnum = crate.lines.s,
		end_lnum = crate.lines.e - 1,
		col = crate.explicit_name_col.s,
		end_col = crate.explicit_name_col.e,
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
		-- elseif scope == PackageScope.DEF then
		-- 	if crate.def then
		-- 		d.lnum = crate.def.line
		-- 		d.end_lnum = crate.def.line
		-- 		d.col = crate.def.col.s
		-- 		d.end_col = crate.def.col.e
		-- 	end
	end

	return d
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

		if s.invalid then
			table.insert(
				diagnostics,
				section_diagnostic(s, M.NpackagesDiagnosticKind.SECTION_INVALID, vim.diagnostic.severity.WARN)
			)
		elseif s_cache[key] then
			table.insert(
				diagnostics,
				section_diagnostic(s_cache[key], M.NpackagesDiagnosticKind.SECTION_DUP, vim.diagnostic.severity.ERROR)
			)
			table.insert(
				diagnostics,
				section_diagnostic(s, M.NpackagesDiagnosticKind.SECTION_DUP, vim.diagnostic.severity.ERROR)
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
				package_diagnostic(cache[key], M.NpackagesDiagnosticKind.PACKAGE_DUP, vim.diagnostic.severity.ERROR)
			)
			table.insert(
				diagnostics,
				package_diagnostic(c, M.NpackagesDiagnosticKind.PACKAGE_DUP, vim.diagnostic.severity.ERROR)
			)
		else
			cache[key] = c
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
	local newest, newest_pre = util.get_newest(versions, nil)
	newest = newest or newest_pre

	---@type PackageInfo
	local info = {
		lines = package.lines,
		vers_line = package.vers and package.vers.line or package.lines.s,
		match_kind = M.MatchKind.NOMATCH,
	}
	local diagnostics = {}

	if package.dep_kind == DepKind.REGISTRY then
		if api_package then
			if api_package.name ~= package:package() then
				table.insert(
					diagnostics,
					package_diagnostic(
						package,
						M.NpackagesDiagnosticKind.CRATE_NAME_CASE,
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
				info.match_kind = M.MatchKind.VERSION

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
						package_diagnostic(
							package,
							M.NpackagesDiagnosticKind.VERS_UPGRADE,
							vim.diagnostic.severity.WARN,
							PackageScope.VERS
						)
					)
				end

				if match then
					-- found a match
					info.match_kind = M.MatchKind.VERSION
				elseif match_pre then
					-- found a pre-release match
					info.match_kind = M.MatchKind.PRERELEASE
					table.insert(
						diagnostics,
						package_diagnostic(
							package,
							M.NpackagesDiagnosticKind.VERS_PRE,
							vim.diagnostic.severity.ERROR,
							PackageScope.VERS
						)
					)
				elseif match_yanked then
					-- found a yanked match
					info.match_kind = M.MatchKind.YANKED
					table.insert(
						diagnostics,
						package_diagnostic(
							package,
							M.NpackagesDiagnosticKind.VERS_YANKED,
							vim.diagnostic.severity.ERROR,
							PackageScope.VERS
						)
					)
				else
					-- no match found
					local kind = M.NpackagesDiagnosticKind.VERS_NOMATCH
					if not package.vers then
						kind = M.NpackagesDiagnosticKind.PACKAGE_NOVERS
					end
					table.insert(
						diagnostics,
						package_diagnostic(package, kind, vim.diagnostic.severity.ERROR, PackageScope.VERS)
					)
				end
			end
		else
			table.insert(
				diagnostics,
				package_diagnostic(
					package,
					M.NpackagesDiagnosticKind.PACKAGE_ERROR_FETCHING,
					vim.diagnostic.severity.ERROR,
					PackageScope.VERS
				)
			)
		end
	end

	return info, diagnostics
end

---@param package JsonPackage
---@param _ ApiVersion
---@param deps ApiDependency[]
---@return NpackagesDiagnostic[]
function M.process_package_deps(package, _, deps)
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
