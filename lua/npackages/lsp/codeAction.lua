local state = require("npackages.lsp.state")
local types = require("npackages.types")
local util = require("npackages.util")
local analyzer = require("npackages.lsp.analyzer")
local Span = types.Span
local NpackagesDiagnosticKind = analyzer.NpackagesDiagnosticKind

local M = {}

------@param params lsp.CodeActionParams
---function M.open_homepage(params)
---	-- local buf = util.current_buf()
---	local line = params.range.start.line
---	local packages = util.get_lsp_packages(params.textDocument.uri, Span.pos(line))
---	local _, crate = next(packages)
---	if crate then
---		local crate_info = state.api_cache[crate:package()]
---		if crate_info and crate_info.homepage then
---			util.open_url(crate_info.homepage)
---		else
---			logger.info(string.format("The crate '%s' has no homepage specified", crate:package()))
---		end
---	end
---end
---
------@param params lsp.CodeActionParams
---function M.open_repository(params)
---	-- local buf = util.current_buf()
---	local line = params.range.start.line
---	local packages = util.get_lsp_packages(params.textDocument.uri, Span.pos(line))
---	local _, crate = next(packages)
---	if crate then
---		local crate_info = state.api_cache[crate:package()]
---		if crate_info and crate_info.repository then
---			util.open_url(crate_info.repository)
---		else
---			logger.info(string.format("The crate '%s' has no repository specified", crate:package()))
---		end
---	end
---end

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

---@param uri lsp.DocumentUri
---@param kind lsp.CodeActionKind
---@param title string
---@param edits lsp.TextEdit[]
---@return lsp.CodeAction
local function to_code_action(uri, kind, title, edits)
	---@type lsp.CodeAction
	return {
		title = title,
		kind = kind,
		edit = {
			changes = {
				[uri] = edits,
			},
		},
	}
end

---@param params lsp.CodeActionParams
---@return lsp.CodeAction[]
function M.get(params)
	local doc = state.documents[params.textDocument.uri]
	local actions = {}

	for _, d in ipairs(params.context.diagnostics) do
		if d.code == NpackagesDiagnosticKind.SECTION_DUP then
			local d_range = {
				start = d.range.start,
				["end"] = { line = d.range["end"].line + 1, character = d.range.start.character },
			}
			local text_edit = { range = d_range, newText = "" }
			table.insert(actions, to_code_action(doc.uri, "quickfix", "Remove duplicate section", { text_edit }))
		end
		if d.code == NpackagesDiagnosticKind.SECTION_INVALID then
			local d_range = {
				start = d.range.start,
				["end"] = { line = d.range["end"].line + 1, character = d.range.start.character },
			}
			local text_edit = { range = d_range, newText = "" }
			table.insert(actions, to_code_action(doc.uri, "quickfix", "Remove invalid section", { text_edit }))
		end
		if d.code == NpackagesDiagnosticKind.PACKAGE_DUP then
			local d_range = {
				start = { line = d.range.start.line, character = 0 },
				["end"] = { line = d.range["end"].line + 1, character = 0 },
			}
			local text_edit = { range = d_range, newText = "" }
			table.insert(actions, to_code_action(doc.uri, "quickfix", "Remove duplicate package", { text_edit }))
		end
	end

	local range = params.range
	local line = range.start.line
	local current_line_pkgs = util.get_lsp_packages(doc.uri, Span.pos(line))
	local line_key, line_pkg = next(current_line_pkgs)
	local diagnostics = state.diagnostics[doc.uri]

	if line_pkg then
		local info = util.get_lsp_package_info(doc.uri, line_key)
		if info then
			for _, d in ipairs(diagnostics) do
				if d.range.start.line == line and d.range.start.character == range.start.character then
					if info.vers_update then
						local version = info.vers_update.parsed:display()
						local text_edit = { range = d.range, newText = version }
						table.insert(actions, to_code_action(doc.uri, "source", "Update package", { text_edit }))
					end
					if info.vers_upgrade then
						local version = info.vers_upgrade.parsed:display()
						local text_edit = { range = d.range, newText = version }
						table.insert(actions, to_code_action(doc.uri, "source", "Upgrade package", { text_edit }))
					end
				end
			end
		end
	end

	---@type lsp.TextEdit[]
	local update_all_edits = {}
	---@type lsp.TextEdit[]
	local upgrade_all_edits = {}
	for _, d in pairs(diagnostics) do
		if d.code == NpackagesDiagnosticKind.VERS_UPGRADE then
			local d_packages = util.get_lsp_packages(doc.uri, Span.pos(d.range.start.line))
			local d_line, d_pkg = next(d_packages)
			if d_pkg then
				local info = util.get_lsp_package_info(doc.uri, d_line)
				if info then
					if info.vers_update then
						local version = info.vers_update.parsed:display()
						local text_edit = { range = d.range, newText = version }
						table.insert(update_all_edits, text_edit)
					end
					if info.vers_upgrade then
						local version = info.vers_upgrade.parsed:display()
						local text_edit = { range = d.range, newText = version }
						table.insert(upgrade_all_edits, text_edit)
					end
				end
			end
		end
	end

	if #update_all_edits > 0 then
		table.insert(actions, to_code_action(doc.uri, "source", "Update all packages", update_all_edits))
	end

	if #upgrade_all_edits > 0 then
		table.insert(actions, to_code_action(doc.uri, "source", "Upgrade all packages", upgrade_all_edits))
	end

	if line_pkg then
		---@type lsp.CodeAction
		local cmd = {
			title = "Open npmjs.org",
			---@type lsp.CodeActionKind
			kind = "refactor.rewrite",
			---@type lsp.Command
			command = {
				title = "Open npmjs.org",
				command = "npackages",
				arguments = {
					function()
						M.open_npmjs(params)
					end,
				},
			},
		}
		table.insert(actions, cmd)
	end

	return actions
end

return M
