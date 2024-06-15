local async = require("npackages.async")
local state = require("npackages.lsp.state")
local plugin = require("npackages.state")
local core = require("npackages.lsp.core")

local textDocument = {}

---@param params lsp.DidOpenTextDocumentParams
---@param callback fun()
function textDocument.didOpen(params, callback)
	local doc = params.textDocument
	state.documents[doc.uri] = doc

	core.update(doc.uri)
	if plugin.cfg.autoupdate then
		core.inner_throttled_update = async.throttle(function()
			core.update(doc.uri)
		end, plugin.cfg.autoupdate_throttle)
	end

	callback()
end

---@param params lsp.DidChangeTextDocumentParams
---@param callback fun()
function textDocument.didChange(params, callback)
	local doc = params.textDocument
	for _, change in ipairs(params.contentChanges) do
		state.documents[doc.uri].text = change.text
	end

	-- core.update(doc.uri)
	core.throttled_update(vim.uri_to_bufnr(doc.uri), false)

	callback()
end

---@param params lsp.DidSaveTextDocumentParams
---@param callback fun()
function textDocument.didSave(params, callback)
	local doc = params.textDocument
	state.documents[doc.uri].text = params.text

	core.update(doc.uri)

	callback()
end

---@param params lsp.DidCloseTextDocumentParams
---@param callback fun()
function textDocument.didClose(params, callback)
	local doc = params.textDocument
	state.documents[doc.uri] = nil

	callback()
end

return textDocument
