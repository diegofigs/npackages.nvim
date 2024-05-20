local edit = require("npackages.edit")
local state = require("npackages.state")
local types = require("npackages.types")
local util = require("npackages.util")
local NpackagesDiagnosticKind = types.NpackagesDiagnosticKind
local Span = types.Span

local M = {}

M.add = require("npackages.actions.add")
M.update = require("npackages.actions.update")
M.delete = require("npackages.actions.delete")
M.install = require("npackages.actions.install")
M.change_version = require("npackages.actions.change_version")

---@class NpackagesAction
---@field name string
---@field action function

---@param alt boolean|nil
function M.upgrade_package(alt)
	local buf = util.current_buf()
	local line = util.cursor_pos()
	local packages = util.get_line_packages(buf, Span.pos(line))
	local info = util.get_buf_info(buf)
	if next(packages) and info then
		edit.upgrade_packages(buf, packages, info, alt)
	end
end

---@param alt boolean|nil
function M.upgrade_packages(alt)
	local buf = util.current_buf()
	local lines = util.selected_lines()
	local packages = util.get_line_packages(buf, lines)
	local info = util.get_buf_info(buf)
	if next(packages) and info then
		edit.upgrade_packages(buf, packages, info, alt)
	end
end

---@param alt boolean|nil
function M.upgrade_all_packages(alt)
	local buf = util.current_buf()
	local cache = state.buf_cache[buf]
	if cache.packages and cache.info then
		edit.upgrade_packages(buf, cache.packages, cache.info, alt)
	end
end

---@param alt boolean|nil
function M.update_package(alt)
	local buf = util.current_buf()
	local line = util.cursor_pos()
	local packages = util.get_line_packages(buf, Span.pos(line))
	local info = util.get_buf_info(buf)
	if next(packages) and info then
		edit.update_packages(buf, packages, info, alt)
	end
end

function M.update_packages(alt)
	local buf = util.current_buf()
	local lines = util.selected_lines()
	local packages = util.get_line_packages(buf, lines)
	local info = util.get_buf_info(buf)
	if next(packages) and info then
		edit.update_packages(buf, packages, info, alt)
	end
end

---@param alt boolean|nil
function M.update_all_packages(alt)
	local buf = util.current_buf()
	local cache = state.buf_cache[buf]
	if cache.packages and cache.info then
		edit.update_packages(buf, cache.packages, cache.info, alt)
	end
end

function M.open_homepage()
	local buf = util.current_buf()
	local line = util.cursor_pos()
	local packages = util.get_line_packages(buf, Span.pos(line))
	local _, crate = next(packages)
	if crate then
		local crate_info = state.api_cache[crate:package()]
		if crate_info and crate_info.homepage then
			util.open_url(crate_info.homepage)
		else
			util.notify(vim.log.levels.INFO, "The crate '%s' has no homepage specified", crate:package())
		end
	end
end

function M.open_repository()
	local buf = util.current_buf()
	local line = util.cursor_pos()
	local packages = util.get_line_packages(buf, Span.pos(line))
	local _, crate = next(packages)
	if crate then
		local crate_info = state.api_cache[crate:package()]
		if crate_info and crate_info.repository then
			util.open_url(crate_info.repository)
		else
			util.notify(vim.log.levels.INFO, "The crate '%s' has no repository specified", crate:package())
		end
	end
end

function M.open_npmjs()
	local buf = util.current_buf()
	local line = util.cursor_pos()
	local packages = util.get_line_packages(buf, Span.pos(line))
	local _, crate = next(packages)
	if crate then
		util.open_url(util.package_url(crate:package()))
	end
end

---@param buf integer
---@param crate JsonPackage
---@param name string
---@return fun()
local function rename_package_package_action(buf, crate, name)
	return function()
		edit.rename_package_package(buf, crate, name)
	end
end

---@param buf integer
---@param d NpackagesDiagnostic
---@return fun()
local function remove_diagnostic_range_action(buf, d)
	return function()
		vim.api.nvim_buf_set_text(buf, d.lnum, d.col, d.end_lnum, d.end_col, {})
	end
end

---@param buf integer
---@param lines Span
---@return fun()
local function remove_lines_action(buf, lines)
	return function()
		vim.api.nvim_buf_set_lines(buf, lines.s, lines.e, false, {})
	end
end

---@return NpackagesAction[]
function M.get_actions()
	---@type NpackagesAction[]
	local actions = {}

	local buf = util.current_buf()
	local line, col = util.cursor_pos()
	local packages = util.get_line_packages(buf, Span.pos(line))
	local key, pkg = next(packages)

	local diagnostics = util.get_buf_diagnostics(buf) or {}
	for _, d in ipairs(diagnostics) do
		if not d:contains(line, col) then
			goto continue
		end

		if d.kind == NpackagesDiagnosticKind.SECTION_DUP then
			table.insert(actions, {
				name = "remove_duplicate_section",
				action = remove_diagnostic_range_action(buf, d),
			})
		elseif d.kind == NpackagesDiagnosticKind.SECTION_DUP_ORIG then
			table.insert(actions, {
				name = "remove_original_section",
				action = remove_lines_action(buf, d.data["lines"]),
			})
		elseif d.kind == NpackagesDiagnosticKind.SECTION_INVALID then
			table.insert(actions, {
				name = "remove_invalid_dependency_section",
				action = remove_diagnostic_range_action(buf, d),
			})
		elseif d.kind == NpackagesDiagnosticKind.CRATE_DUP then
			table.insert(actions, {
				name = "remove_duplicate_package",
				action = remove_diagnostic_range_action(buf, d),
			})
		elseif d.kind == NpackagesDiagnosticKind.CRATE_DUP_ORIG then
			table.insert(actions, {
				name = "remove_original_package",
				action = remove_diagnostic_range_action(buf, d),
			})
		elseif d.kind == NpackagesDiagnosticKind.CRATE_NAME_CASE then
			table.insert(actions, {
				name = "rename_package",
				action = rename_package_package_action(buf, d.data["crate"], d.data["crate_name"]),
			})
		end

		::continue::
	end

	if pkg then
		local info = util.get_package_info(buf, key)
		if info then
			if info.vers_update then
				table.insert(actions, {
					name = "update_package",
					action = M.update_package,
				})
			end
			if info.vers_upgrade then
				table.insert(actions, {
					name = "upgrade_package",
					action = M.upgrade_package,
				})
			end
		end

		-- table.insert(actions, {
		-- 	name = "open_documentation",
		-- 	action = M.open_documentation,
		-- })
		table.insert(actions, {
			name = "open_npmjs.org",
			action = M.open_npmjs,
		})
		-- table.insert(actions, {
		-- 	name = "open_lib.rs",
		-- 	action = M.open_lib_rs,
		-- })
	end

	table.insert(actions, {
		name = "update_all_packages",
		action = M.update_all_packages,
	})
	table.insert(actions, {
		name = "upgrade_all_packages",
		action = M.upgrade_all_packages,
	})

	return actions
end

return M
