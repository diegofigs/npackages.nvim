local state = require("npackages.lsp.state")
local scanner = require("npackages.lsp.scanner")
local analyzer = require("npackages.lsp.analyzer")
local progress = require("npackages.lsp.progress")

local M = {}

---@param params lsp.DocumentSymbolParams
---@return lsp.DocumentSymbol[]
function M.get(params)
	local doc = state.documents[params.textDocument.uri]
	if doc == nil then
		return {}
	end

	local workDoneToken = params.workDoneToken or "1"
	progress.begin(workDoneToken, "Document Symbols")

	local sections, packages = scanner.scan_package_doc(vim.split(doc.text, "\n"))
	local section_set, package_set = analyzer.analyze_package_json(sections, packages)

	---@type lsp.DocumentSymbol[]
	local symbols = {}
	local prod_idx = 0
	local dev_idx = 0

	for _, section in pairs(section_set) do
		---@type lsp.DocumentSymbol
		local symbol = {
			name = section.text,
			kind = 3,
			range = section.range,
			selectionRange = section.name_range,
			children = {},
		}
		table.insert(symbols, symbol)
		if section.kind == 1 then
			prod_idx = #symbols
		end
		if section.kind == 2 then
			dev_idx = #symbols
		end
	end

	for _, pkg in pairs(package_set) do
		---@type lsp.DocumentSymbol
		local symbol = {
			name = pkg.explicit_name,
			kind = 4,
			range = pkg.range,
			selectionRange = pkg.range,
			children = {
				{ name = pkg.vers.text, kind = 8, range = pkg.vers.range, selectionRange = pkg.vers.range },
			},
		}
		if pkg.section.kind == 1 then
			table.insert(symbols[prod_idx].children, symbol)
		end
		if pkg.section.kind == 2 then
			table.insert(symbols[dev_idx].children, symbol)
		end
	end

	progress.finish(workDoneToken)

	return symbols
end

return M
