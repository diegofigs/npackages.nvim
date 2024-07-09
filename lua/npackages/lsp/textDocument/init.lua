local state = require("npackages.lsp.state")
local hover = require("npackages.lsp.textDocument.hover")
local codeAction = require("npackages.lsp.textDocument.codeAction")
local diagnostic = require("npackages.lsp.textDocument.diagnostic")
local completion = require("npackages.lsp.textDocument.completion")
local documentSymbol = require("npackages.lsp.textDocument.documentSymbol")
local semanticTokens = require("npackages.lsp.textDocument.semanticTokens")

local textDocument = {}

---@param params lsp.DidOpenTextDocumentParams
---@param callback fun(err, res)
function textDocument.didOpen(params, callback)
	local doc = params.textDocument
	state.documents[doc.uri] = doc

	callback(nil, nil)
end

---@param params lsp.DidChangeTextDocumentParams
---@param callback fun(err, res)
function textDocument.didChange(params, callback)
	local doc = params.textDocument
	for _, change in ipairs(params.contentChanges) do
		state.documents[doc.uri].text = change.text
	end

	callback(nil, nil)
end

---@param params lsp.DidSaveTextDocumentParams
---@param callback fun(err, res)
function textDocument.didSave(params, callback)
	callback(nil, nil)
end

---@param params lsp.DidCloseTextDocumentParams
---@param callback fun(err, res)
function textDocument.didClose(params, callback)
	local doc = params.textDocument
	state.documents[doc.uri] = nil

	callback(nil, nil)
end

---@param params lsp.HoverParams
---@param callback fun(err: nil, res: lsp.Hover|nil)
textDocument.hover = function(params, callback)
	local result = hover.hover(params)
	callback(nil, result)
end

---@param params lsp.CodeActionParams
---@param callback fun(err: nil, res: lsp.CodeAction[])
textDocument.codeAction = function(params, callback)
	local result = codeAction.get(params)
	callback(nil, result)
end

---@param params lsp.DocumentDiagnosticParams
---@param callback fun(err, res: lsp.DocumentDiagnosticReport)
textDocument.diagnostic = function(params, callback)
	diagnostic.diagnose(params, callback)
end

---@param params lsp.CompletionParams
---@param callback fun(err, result: vim.lsp.CompletionResult)
textDocument.completion = function(params, callback)
	completion.complete(params, callback)
end

---@param params lsp.DocumentSymbolParams
---@param callback fun(err, res: lsp.DocumentSymbol[])
textDocument.documentSymbol = function(params, callback)
	local result = documentSymbol.get(params)
	callback(nil, result)
end

---@param params lsp.SemanticTokensParams
---@param callback fun(err, res: lsp.SemanticTokens)
textDocument.semanticTokens = function(params, callback)
	local result = semanticTokens.get(params)
	callback(nil, result)
end

return textDocument
