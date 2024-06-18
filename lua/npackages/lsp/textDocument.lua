local state = require("npackages.lsp.state")
local core = require("npackages.lsp.core")

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
	state.documents[doc.uri].text = params.text

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

return textDocument
