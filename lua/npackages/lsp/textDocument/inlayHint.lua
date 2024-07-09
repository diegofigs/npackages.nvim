local state = require("npackages.lsp.state")
local scanner = require("npackages.lsp.scanner")

local M = {}

---@param params lsp.InlayHintParams
---@return lsp.InlayHint[]
function M.get(params)
	local doc = state.documents[params.textDocument.uri]
	if doc == nil then
		return {}
	end

	local lines = vim.split(doc.text, "\n")
	if not lines then
		return {}
	end

	local sections, packages, scripts = scanner.scan_package_doc(lines)
	local inlay_hints = {}

	-- Count packages in each section
	local package_counts = { [1] = 0, [2] = 0 }
	for _, pkg in pairs(packages) do
		package_counts[pkg.section.kind] = package_counts[pkg.section.kind] + 1
	end

	-- Count scripts
	local script_count = #scripts

	-- Create inlay hints for each section
	for _, section in pairs(sections) do
		local count_text = ""
		if section.kind == 1 or section.kind == 2 then
			count_text = string.format("(%d packages)", package_counts[section.kind])
		elseif section.kind == 3 then
			count_text = string.format("(%d scripts)", script_count)
		end

		table.insert(inlay_hints, {
			position = section.name_range["end"],
			label = count_text,
			kind = 1, -- InlayHintKind.Text
		})
	end

	return inlay_hints
end

return M
