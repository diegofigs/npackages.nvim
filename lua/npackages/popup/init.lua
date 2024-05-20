local popup = require("npackages.popup.common")
local popup_package = require("npackages.popup.package")
local popup_versions = require("npackages.popup.versions")
local json = require("npackages.json")
local state = require("npackages.state")
local JsonPackageSyntax = json.JsonPackageSyntax
local types = require("npackages.types")
local Span = types.Span
local util = require("npackages.util")

local M = {}

---@class LinePackageInfo
---@field pref PopupType
---@field crate JsonPackage
---@field versions ApiVersion[]
---@field newest ApiVersion|nil

---@return LinePackageInfo|nil
local function line_crate_info()
	local buf = util.current_buf()
	local line, col = util.cursor_pos()

	local packages = util.get_line_packages(buf, Span.new(line, line + 1))
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
		pref = popup.Type.JSON,
	}

	local function versions_info()
		info.pref = popup.Type.VERSIONS
	end

	if crate.syntax == JsonPackageSyntax.PLAIN then
		if crate.vers.col:moved(-1, 1):contains(col) then
			versions_info()
		else
			-- crate_info()
		end
	elseif crate.syntax == JsonPackageSyntax.TABLE then
		if crate.vers and line == crate.vers.line then
			versions_info()
		else
			-- crate_info()
		end
	elseif crate.syntax == JsonPackageSyntax.INLINE_TABLE then
		if crate.vers and crate.vers.decl_col:contains(col) then
			versions_info()
		else
			-- crate_info()
		end
	end

	return info
end

---@return boolean
function M.available()
	return line_crate_info() ~= nil
end

function M.show()
	if popup.win and vim.api.nvim_win_is_valid(popup.win) then
		popup.focus()
		return
	end

	local info = line_crate_info()
	if not info then
		return
	end

	if info.pref == popup.Type.JSON then
		local crate = state.api_cache[info.crate:package()]
		if crate then
			popup_package.open(crate, {})
		end
	elseif info.pref == popup.Type.VERSIONS then
		popup_versions.open(info.crate, info.versions, {})
		-- elseif info.pref == popup.Type.DEPENDENCIES then
		-- 	popup_deps.open(info.crate:package(), info.newest, {})
	end
end

function M.focus()
	popup.focus()
end

function M.hide()
	popup.hide()
end

function M.show_package()
	if popup.win and vim.api.nvim_win_is_valid(popup.win) then
		if popup.type == popup.Type.JSON then
			popup.focus()
			return
		else
			popup.hide()
		end
	end

	local info = line_crate_info()
	if not info then
		return
	end

	local crate = state.api_cache[info.crate:package()]
	if crate then
		popup_package.open(crate, {})
	end
end

function M.show_versions()
	if popup.win and vim.api.nvim_win_is_valid(popup.win) then
		if popup.type == popup.Type.VERSIONS then
			popup.focus()
			return
		else
			popup.hide()
		end
	end

	local info = line_crate_info()
	if not info then
		return
	end

	popup_versions.open(info.crate, info.versions, {})
end

function M.show_dependencies()
	if popup.win and vim.api.nvim_win_is_valid(popup.win) then
		if popup.type == popup.Type.DEPENDENCIES then
			popup.focus()
			return
		else
			popup.hide()
		end
	end

	local info = line_crate_info()
	if not info then
		return
	end

	-- popup_deps.open(info.crate:package(), info.newest, {})
end

return M
