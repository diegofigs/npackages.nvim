local state = require("npackages.lsp.state")
local progress = require("npackages.lsp.progress")
local documentSymbol = require("npackages.lsp.textDocument.documentSymbol")

local M = {}

---@type lsp.SemanticTokensLegend
M.legend = {
	--- Namespaces represent high level sections
	--- Property represents package names inside sections
	--- String represents package versions
	--- Function represents script names
	tokenTypes = { "namespace", "property", "string", "function" },
	tokenModifiers = {},
}

---@param params lsp.SemanticTokensParams
---@return lsp.SemanticTokens
function M.get(params)
	local doc = state.documents[params.textDocument.uri]
	if doc == nil then
		return {}
	end

	local workDoneToken = params.workDoneToken
	progress.begin(workDoneToken, "Semantic Tokens")

	local doc_symbols = documentSymbol.get({ textDocument = { uri = doc.uri } })

	---@type uinteger[][]
	local tokens = {}
	local last_line = 0
	local last_start = 0

	for i, namespace_symbol in ipairs(doc_symbols) do
		---@type uinteger[]
		local namespace_token = {}

		if i == 1 then
			-- First section
			table.insert(namespace_token, namespace_symbol.range.start.line)
			table.insert(namespace_token, namespace_symbol.range.start.character)
		else
			-- Subsequent sections
			table.insert(namespace_token, namespace_symbol.range.start.line - last_line)
			if namespace_symbol.range.start.line == last_line then
				table.insert(namespace_token, namespace_symbol.range.start.character - last_start)
			else
				table.insert(namespace_token, namespace_symbol.range.start.character)
			end
		end

		local length = namespace_symbol.selectionRange["end"].character
			- namespace_symbol.selectionRange.start.character
		table.insert(namespace_token, length)
		table.insert(namespace_token, 0) -- tokenType for section
		table.insert(namespace_token, 0) -- tokenModifiers

		last_line = namespace_symbol.range.start.line
		last_start = namespace_symbol.range.start.character

		table.insert(tokens, namespace_token)

		for _, property_symbol in ipairs(namespace_symbol.children) do
			---@type uinteger[]
			local property_token = {}

			table.insert(property_token, property_symbol.range.start.line - last_line)
			if property_symbol.range.start.line == last_line then
				table.insert(property_token, property_symbol.range.start.character - last_start)
			else
				table.insert(property_token, property_symbol.range.start.character)
			end

			local property_length = property_symbol.selectionRange["end"].character
				- property_symbol.selectionRange.start.character
			table.insert(property_token, property_length)
			if property_symbol.kind == 4 then
				table.insert(property_token, 1) -- tokenType for package
			else
				table.insert(property_token, 3) -- tokenType for script
			end
			table.insert(property_token, 0) -- tokenModifiers

			last_line = property_symbol.range.start.line
			last_start = property_symbol.range.start.character

			table.insert(tokens, property_token)

			if property_symbol.children then
				for _, string_symbol in ipairs(property_symbol.children) do
					---@type uinteger[]
					local value_token = {}

					table.insert(value_token, string_symbol.range.start.line - last_line)
					if string_symbol.range.start.line == last_line then
						table.insert(value_token, string_symbol.range.start.character - last_start)
					else
						table.insert(value_token, string_symbol.range.start.character)
					end

					local value_length = string_symbol.selectionRange["end"].character
						- string_symbol.selectionRange.start.character
					table.insert(value_token, value_length)
					table.insert(value_token, 2) -- tokenType for version
					table.insert(value_token, 0) -- tokenModifiers

					last_line = string_symbol.range.start.line
					last_start = string_symbol.range.start.character

					table.insert(tokens, value_token)
				end
			end
		end
	end

	progress.finish(workDoneToken)

	---@type lsp.SemanticTokens
	local result = { data = {} }

	for _, t in ipairs(tokens) do
		for _, v in ipairs(t) do
			table.insert(result.data, v)
		end
	end

	return result
end

return M
