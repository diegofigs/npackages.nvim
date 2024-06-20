local state = require("npackages.lsp.state")
local core = require("npackages.lsp.core")
local hover = require("npackages.lsp.textDocument.hover")
local codeAction = require("npackages.lsp.textDocument.codeAction")
local diagnostic = require("npackages.lsp.textDocument.diagnostic")
local completion = require("npackages.lsp.textDocument.completion")

local textDocument = {}

---@param params lsp.DidOpenTextDocumentParams
---@param callback fun(err, res)
function textDocument.didOpen(params, callback)
	local doc = params.textDocument
	state.documents[doc.uri] = doc

	-- if plugin.cfg.autoupdate then
	-- 	core.inner_throttled_update = async.throttle(function()
	-- 		core.update(doc.uri)
	-- 	end, plugin.cfg.autoupdate_throttle)
	-- end

	core.update(doc.uri)
	callback(nil, nil)
end

---@param params lsp.DidChangeTextDocumentParams
---@param callback fun(err, res)
function textDocument.didChange(params, callback)
	local doc = params.textDocument
	for _, change in ipairs(params.contentChanges) do
		state.documents[doc.uri].text = change.text
	end

	-- core.throttled_update(vim.uri_to_bufnr(doc.uri), false)

	core.update(doc.uri)
	callback(nil, nil)
end

---@param params lsp.DidSaveTextDocumentParams
---@param callback fun(err, res)
function textDocument.didSave(params, callback)
	local doc = params.textDocument

	core.update(doc.uri)
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
---@param callback fun(err: nil, res: lsp.CodeAction[]|nil)
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
---@param callback fun(err, result: vim.lsp.CompletionResult|nil)
textDocument.completion = function(params, callback)
	completion.complete(params, callback)
end

return textDocument
