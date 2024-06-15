local state = require("npackages.lsp.state")
local types = require("npackages.types")
local util = require("npackages.util")
local analyzer = require("npackages.lsp.analyzer")
local Span = types.Span
local DiagnosticCodes = analyzer.DiagnosticCodes

local M = {}

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
		if d.code == DiagnosticCodes.SECTION_DUP then
			local d_range = {
				start = d.range.start,
				["end"] = { line = d.range["end"].line + 1, character = d.range.start.character },
			}
			local text_edit = { range = d_range, newText = "" }
			table.insert(actions, to_code_action(doc.uri, "quickfix", "Remove duplicate section", { text_edit }))
		end
		if d.code == DiagnosticCodes.SECTION_INVALID then
			local d_range = {
				start = d.range.start,
				["end"] = { line = d.range["end"].line + 1, character = d.range.start.character },
			}
			local text_edit = { range = d_range, newText = "" }
			table.insert(actions, to_code_action(doc.uri, "quickfix", "Remove invalid section", { text_edit }))
		end
		if d.code == DiagnosticCodes.PACKAGE_DUP then
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
		local cache = state.doc_cache[doc.uri]
		local info = cache.info[line_key]
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
		if d.code == DiagnosticCodes.VERS_UPGRADE then
			local d_packages = util.get_lsp_packages(doc.uri, Span.pos(d.range.start.line))
			local d_line, d_pkg = next(d_packages)
			if d_pkg then
				local cache = state.doc_cache[doc.uri]
				local info = cache.info[d_line]
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
		local info = state.api_cache[line_pkg:package()]
		---@type lsp.CodeAction
		local repo_cmd = {
			title = "Open homepage",
			kind = "",
			command = {
				title = "Open url",
				command = "open_url",
				arguments = { info.homepage },
			},
		}
		table.insert(actions, repo_cmd)

		---@type lsp.CodeAction
		local homepage_cmd = {
			title = "Open repository",
			kind = "",
			command = {
				title = "Open url",
				command = "open_url",
				arguments = { info.repository },
			},
		}
		table.insert(actions, homepage_cmd)

		---@type lsp.CodeAction
		local npmjs_cmd = {
			title = "Open npmjs.org",
			kind = "",
			command = {
				title = "Open url",
				command = "open_url",
				arguments = { util.package_url(line_pkg:package()) },
			},
		}
		table.insert(actions, npmjs_cmd)
	end

	return actions
end

return M
