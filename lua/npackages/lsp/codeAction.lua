local edit = require("npackages.edit")
local state = require("npackages.lsp.state")
local types = require("npackages.types")
local util = require("npackages.util")
local Span = types.Span
local NpackagesDiagnosticKind = types.NpackagesDiagnosticKind

local M = {}

---@param params lsp.CodeActionParams
---@param alt boolean|nil
function M.upgrade_package(params, alt)
	local buf = vim.uri_to_bufnr(params.textDocument.uri)
	local line = params.range.start.line
	local packages = util.get_lsp_packages(params.textDocument.uri, Span.pos(line))
	local info = util.get_lsp_info(params.textDocument.uri)
	if next(packages) and info then
		edit.upgrade_packages(buf, packages, info, alt)
	end
end

---@param params lsp.CodeActionParams
---@param alt boolean|nil
function M.upgrade_packages(params, alt)
	local buf = vim.uri_to_bufnr(params.textDocument.uri)
	local lines = util.selected_lines()
	local packages = util.get_lsp_packages(params.textDocument.uri, lines)
	local info = util.get_lsp_info(params.textDocument.uri)
	if next(packages) and info then
		edit.upgrade_packages(buf, packages, info, alt)
	end
end

---@param params lsp.CodeActionParams
---@param alt boolean|nil
function M.upgrade_all_packages(params, alt)
	local buf = vim.uri_to_bufnr(params.textDocument.uri)
	local cache = state.doc_cache[params.textDocument.uri]
	if cache.packages and cache.info then
		edit.upgrade_packages(buf, cache.packages, cache.info, alt)
	end
end

---@param params lsp.CodeActionParams
---@param alt boolean|nil
function M.update_package(params, alt)
	local buf = vim.uri_to_bufnr(params.textDocument.uri)
	local line = params.range.start.line
	local packages = util.get_lsp_packages(params.textDocument.uri, Span.pos(line))
	local info = util.get_lsp_info(params.textDocument.uri)
	if next(packages) and info then
		edit.update_packages(buf, packages, info, alt)
	end
end

---@param params lsp.CodeActionParams
---@param alt boolean|nil
function M.update_packages(params, alt)
	local buf = vim.uri_to_bufnr(params.textDocument.uri)
	local lines = util.selected_lines()
	local packages = util.get_lsp_packages(params.textDocument.uri, lines)
	local info = util.get_lsp_info(params.textDocument.uri)
	if next(packages) and info then
		edit.update_packages(buf, packages, info, alt)
	end
end

---@param params lsp.CodeActionParams
---@param alt boolean|nil
function M.update_all_packages(params, alt)
	local buf = vim.uri_to_bufnr(params.textDocument.uri)
	local cache = state.doc_cache[params.textDocument.uri]
	if cache.packages and cache.info then
		edit.update_packages(buf, cache.packages, cache.info, alt)
	end
end

---@param params lsp.CodeActionParams
function M.open_homepage(params)
	-- local buf = util.current_buf()
	local line = params.range.start.line
	local packages = util.get_lsp_packages(params.textDocument.uri, Span.pos(line))
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

---@param params lsp.CodeActionParams
function M.open_repository(params)
	-- local buf = util.current_buf()
	local line = params.range.start.line
	local packages = util.get_lsp_packages(params.textDocument.uri, Span.pos(line))
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

---@param params lsp.CodeActionParams
function M.open_npmjs(params)
	-- local buf = util.current_buf()
	local line = params.range.start.line
	local packages = util.get_lsp_packages(params.textDocument.uri, Span.pos(line))
	local _, crate = next(packages)
	if crate then
		util.open_url(util.package_url(crate:package()))
	end
end

---@param params lsp.CodeActionParams
---@return fun()
local function remove_diagnostic_range_action(params)
	local buf = vim.uri_to_bufnr(params.textDocument.uri)
	local range = params.range
	return function()
		vim.api.nvim_buf_set_text(
			buf,
			range.start.line,
			range.start.character,
			range["end"].line + 1,
			range["end"].character,
			{}
		)
	end
end

---@param params lsp.CodeActionParams
local function remove_lines_action(params)
	local buf = vim.uri_to_bufnr(params.textDocument.uri)
	local range = params.range
	return function()
		vim.api.nvim_buf_set_lines(buf, range.start.line, range["end"].line + 1, false, {})
	end
end

local function to_code_action(action)
	local title = util.format_title(action.name)
	---@type lsp.CodeAction
	return {
		title = title,
		---@type lsp.CodeActionKind
		kind = "refactor.rewrite",
		---@type lsp.Command
		command = {
			title = title,
			command = "npackages",
			arguments = { action.action },
		},
	}
end

---@param params lsp.CodeActionParams
---@return lsp.CodeAction[]
function M.get(params)
	local doc = state.documents[params.textDocument.uri]
	local actions = {}

	local range = params.range
	local line = range.start.line
	local col = range.start.character
	local packages = util.get_lsp_packages(doc.uri, Span.pos(line))
	local key, pkg = next(packages)

	local diagnostics = util.get_lsp_diagnostics(doc.uri) or {}
	for _, d in ipairs(diagnostics) do
		if not d:contains(line, col) then
			goto continue
		end

		if d.kind == NpackagesDiagnosticKind.SECTION_DUP then
			table.insert(
				actions,
				to_code_action({
					name = "remove_duplicate_section",
					action = remove_diagnostic_range_action(params),
				})
			)
		end
		if d.kind == NpackagesDiagnosticKind.SECTION_DUP_ORIG then
			table.insert(
				actions,
				to_code_action({
					name = "remove_original_section",
					action = remove_lines_action(params),
				})
			)
		end
		if d.kind == NpackagesDiagnosticKind.SECTION_INVALID then
			table.insert(
				actions,
				to_code_action({
					name = "remove_invalid_dependency_section",
					action = remove_diagnostic_range_action(params),
				})
			)
		end
		if d.kind == NpackagesDiagnosticKind.CRATE_DUP then
			table.insert(
				actions,
				to_code_action({
					name = "remove_duplicate_package",
					action = remove_diagnostic_range_action(params),
				})
			)
		end
		if d.kind == NpackagesDiagnosticKind.CRATE_DUP_ORIG then
			table.insert(
				actions,
				to_code_action({
					name = "remove_original_package",
					action = remove_diagnostic_range_action(params),
				})
			)
		end

		::continue::
	end

	if pkg then
		local info = util.get_lsp_package_info(doc.uri, key)
		if info then
			if info.vers_update then
				table.insert(
					actions,
					to_code_action({
						name = "update_package",
						action = function(alt)
							M.update_package(params, alt)
						end,
					})
				)
			end
			if info.vers_upgrade then
				table.insert(
					actions,
					to_code_action({
						name = "upgrade_package",
						action = function(alt)
							M.upgrade_package(params, alt)
						end,
					})
				)
			end
		end
	end

	table.insert(
		actions,
		to_code_action({
			name = "update_all_packages",
			action = function(alt)
				M.update_all_packages(params, alt)
			end,
		})
	)
	table.insert(
		actions,
		to_code_action({
			name = "upgrade_all_packages",
			action = function(alt)
				M.upgrade_all_packages(params, alt)
			end,
		})
	)

	table.insert(
		actions,
		to_code_action({
			name = "open_npmjs.org",
			action = function()
				M.open_npmjs(params)
			end,
		})
	)

	return actions
end

return M
