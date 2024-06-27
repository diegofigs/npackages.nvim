local state = require("npackages.lsp.state")
local progress = require("npackages.lsp.progress")
local documentSymbol = require("npackages.lsp.textDocument.documentSymbol")

local M = {}

---@type lsp.SemanticTokensLegend
M.legend = {
	tokenTypes = { "namespace", "enum", "enumMember" },
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

	for i, section_symbol in ipairs(doc_symbols) do
		---@type uinteger[]
		local section_token = {}

		if i == 1 then
			-- First section
			table.insert(section_token, section_symbol.range.start.line)
			table.insert(section_token, section_symbol.range.start.character)
		else
			-- Subsequent sections
			table.insert(section_token, section_symbol.range.start.line - last_line)
			if section_symbol.range.start.line == last_line then
				table.insert(section_token, section_symbol.range.start.character - last_start)
			else
				table.insert(section_token, section_symbol.range.start.character)
			end
		end

		local length = section_symbol.selectionRange["end"].character - section_symbol.selectionRange.start.character
		table.insert(section_token, length)
		table.insert(section_token, 0) -- tokenType for section
		table.insert(section_token, 0) -- tokenModifiers

		last_line = section_symbol.range.start.line
		last_start = section_symbol.range.start.character

		table.insert(tokens, section_token)

		for _, pkg_symbol in ipairs(section_symbol.children) do
			---@type uinteger[]
			local pkg_token = {}

			table.insert(pkg_token, pkg_symbol.range.start.line - last_line)
			if pkg_symbol.range.start.line == last_line then
				table.insert(pkg_token, pkg_symbol.range.start.character - last_start)
			else
				table.insert(pkg_token, pkg_symbol.range.start.character)
			end

			local pkg_length = pkg_symbol.selectionRange["end"].character - pkg_symbol.selectionRange.start.character
			table.insert(pkg_token, pkg_length)
			table.insert(pkg_token, 1) -- tokenType for package
			table.insert(pkg_token, 0) -- tokenModifiers

			last_line = pkg_symbol.range.start.line
			last_start = pkg_symbol.range.start.character

			table.insert(tokens, pkg_token)

			for _, version_symbol in ipairs(pkg_symbol.children) do
				---@type uinteger[]
				local version_token = {}

				table.insert(version_token, version_symbol.range.start.line - last_line)
				if version_symbol.range.start.line == last_line then
					table.insert(version_token, version_symbol.range.start.character - last_start)
				else
					table.insert(version_token, version_symbol.range.start.character)
				end

				local version_length = version_symbol.selectionRange["end"].character
					- version_symbol.selectionRange.start.character
				table.insert(version_token, version_length)
				table.insert(version_token, 2) -- tokenType for version
				table.insert(version_token, 0) -- tokenModifiers

				last_line = version_symbol.range.start.line
				last_start = version_symbol.range.start.character

				table.insert(tokens, version_token)
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
