local hover = require("npackages.hover.common")
local hover_package = require("npackages.hover.package")
local hover_versions = require("npackages.hover.versions")
local json = require("npackages.json")
local state = require("npackages.lsp.state")
local JsonPackageSyntax = json.JsonPackageSyntax
local types = require("npackages.types")
local Span = types.Span
local util = require("npackages.util")

local Hover = {}

---@class LinePackageInfo
---@field pref PopupType
---@field crate JsonPackage
---@field versions ApiVersion[]
---@field newest ApiVersion|nil

---@return LinePackageInfo|nil
local function line_crate_info()
	local buf = util.current_buf()
	local line, col = util.cursor_pos()

	local packages = util.get_lsp_packages(vim.uri_from_bufnr(buf), Span.new(line, line + 1))
	local _, crate = next(packages)
	if not crate then
		return
	end

	local api_package = state.api_cache[crate:package()]
	if not api_package then
		return
	end

	local m, p, y = util.get_newest(api_package.versions, crate:vers_reqs())
	local newest = m or p or y or api_package.versions[1]

	---@type LinePackageInfo
	local info = {
		crate = crate,
		versions = api_package.versions,
		newest = newest,
		pref = hover.Type.JSON,
	}

	local function versions_info()
		info.pref = hover.Type.VERSIONS
	end

	if crate.syntax == JsonPackageSyntax.PLAIN then
		if crate.vers.col:moved(-1, 1):contains(col) then
			versions_info()
			-- else
			-- crate_info()
		end
	elseif crate.syntax == JsonPackageSyntax.TABLE then
		if crate.vers and line == crate.vers.line then
			versions_info()
			-- else
			-- crate_info()
		end
	elseif crate.syntax == JsonPackageSyntax.INLINE_TABLE then
		if crate.vers and crate.vers.decl_col:contains(col) then
			versions_info()
			-- else
			-- crate_info()
		end
	end

	return info
end

---@return boolean
function Hover.available()
	return line_crate_info() ~= nil
end

function Hover.show()
	if hover.win and vim.api.nvim_win_is_valid(hover.win) then
		hover.focus()
		return
	end

	local info = line_crate_info()
	if not info then
		return
	end

	if info.pref == hover.Type.JSON then
		local crate = state.api_cache[info.crate:package()]
		if crate then
			hover_package.open(crate, {})
		end
	elseif info.pref == hover.Type.VERSIONS then
		hover_versions.open(info.crate, info.versions, {})
		-- elseif info.pref == popup.Type.DEPENDENCIES then
		-- 	popup_deps.open(info.crate:package(), info.newest, {})
	end
end

function Hover.focus()
	hover.focus()
end

function Hover.hide()
	hover.hide()
end

function Hover.show_package()
	if hover.win and vim.api.nvim_win_is_valid(hover.win) then
		if hover.type == hover.Type.JSON then
			hover.focus()
			return
		else
			hover.hide()
		end
	end

	local info = line_crate_info()
	if not info then
		return
	end

	local crate = state.api_cache[info.crate:package()]
	if crate then
		hover_package.open(crate, {})
	end
end

function Hover.show_versions()
	if hover.win and vim.api.nvim_win_is_valid(hover.win) then
		if hover.type == hover.Type.VERSIONS then
			hover.focus()
			return
		else
			hover.hide()
		end
	end

	local info = line_crate_info()
	if not info then
		return
	end

	hover_versions.open(info.crate, info.versions, {})
end

function Hover.show_dependencies()
	if hover.win and vim.api.nvim_win_is_valid(hover.win) then
		if hover.type == hover.Type.DEPENDENCIES then
			hover.focus()
			return
		else
			hover.hide()
		end
	end

	local info = line_crate_info()
	if not info then
		return
	end

	-- popup_deps.open(info.crate:package(), info.newest, {})
end

return Hover
