local hover = require("npackages.hover.common")
local hover_package = require("npackages.hover.package")
local hover_versions = require("npackages.hover.versions")
local lsp_state = require("npackages.lsp.state")
local analyzer = require("npackages.lsp.analyzer")
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

	local pkg = util.get_package_in_position(vim.uri_from_bufnr(buf), {
		line = line,
		character = 0,
	})

	if not pkg then
		return
	end

	local api_package = lsp_state.api_cache[pkg:package()]
	if not api_package then
		return
	end

	local m, p, y = analyzer.get_newest(api_package.versions, pkg:vers_reqs())
	local newest = m or p or y or api_package.versions[1]

	---@type LinePackageInfo
	local info = {
		crate = pkg,
		versions = api_package.versions,
		newest = newest,
		pref = hover.Type.JSON,
	}

	local function versions_info()
		info.pref = hover.Type.VERSIONS
	end

	if pkg.vers.range.start.character - 1 <= col and col < pkg.vers.range["end"].character + 1 then
		versions_info()
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
		local crate = lsp_state.api_cache[info.crate:package()]
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

	local crate = lsp_state.api_cache[info.crate:package()]
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
