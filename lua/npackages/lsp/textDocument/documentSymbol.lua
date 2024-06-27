local state = require("npackages.lsp.state")
local scanner = require("npackages.lsp.scanner")
local analyzer = require("npackages.lsp.analyzer")
local progress = require("npackages.lsp.progress")

local M = {}

local function split(s, delimiter)
	delimiter = delimiter or " "
	local result = {}
	for word in string.gmatch(s, "(.-)" .. delimiter) do
		table.insert(result, word)
	end
	if #result == 0 then
		return nil
	end
	return result
end

---Compares document symbols' ranges
---@param a lsp.DocumentSymbol
---@param b lsp.DocumentSymbol
---@return boolean
local function compare_symbols(a, b)
	if a.range.start.line < b.range.start.line then
		return true
	elseif a.range.start.line == b.range.start.line then
		return a.range.start.character < b.range.start.character
	else
		return false
	end
end

---Sorts document symbol tree based on ranges
---@param symbols lsp.DocumentSymbol[]
local function sort_symbols(symbols)
	table.sort(symbols, compare_symbols)
	for _, symbol in ipairs(symbols) do
		if symbol.children then
			sort_symbols(symbol.children)
		end
	end
end

---@param params lsp.DocumentSymbolParams
---@return lsp.DocumentSymbol[]
function M.get(params)
	local doc = state.documents[params.textDocument.uri]
	if doc == nil then
		return {}
	end

	local workDoneToken = params.workDoneToken
	progress.begin(workDoneToken, "Document Symbols")

	local lines = split(doc.text, "\n")
	if not lines then
		return {}
	end

	local sections, packages = scanner.scan_package_doc(lines)
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
				{ name = pkg.vers.text, kind = 8, range = pkg.vers.quote, selectionRange = pkg.vers.quote },
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

	sort_symbols(symbols)

	return symbols
end

return M
