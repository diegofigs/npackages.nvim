local nio = require("nio")
local state = require("npackages.lsp.state")
local textDocument = require("npackages.lsp.textDocument")
local completion = require("npackages.lsp.textDocument.completion")
local diagnostic = require("npackages.lsp.textDocument.diagnostic")
local semanticTokens = require("npackages.lsp.textDocument.semanticTokens")
local workspace = require("npackages.lsp.workspace")
local uuid = require("npackages.lib.uuid")
local extmark = require("npackages.ui.extmark")
local methods = vim.lsp.protocol.Methods

local M = {}

---@type lsp.ServerCapabilities
local server_capabilities = {
	textDocumentSync = {
		change = 1,
		openClose = true,
		save = {
			includeText = true,
		},
	},
	diagnosticProvider = {
		workDoneProgress = true,
		workspaceDiagnostics = false,
		interFileDependencies = false,
	},
	documentSymbolProvider = true,
	semanticTokensProvider = {
		legend = semanticTokens.legend,
		full = true,
	},
	codeLensProvider = {
		resolveProvider = false,
	},
	definitionProvider = true,
	inlayHintProvider = true,
}

local handlers = {
	---@param params lsp.InitializeParams
	---@param callback fun(err: nil, result: lsp.InitializeResult)
	[methods.initialize] = function(params, callback)
		local opts = params.initializationOptions or {}
		server_capabilities.codeActionProvider = opts.codeAction or true
		server_capabilities.completionProvider = (opts.completion or nil)
			and {
				triggerCharacters = completion.trigger_characters,
			}
		server_capabilities.hoverProvider = opts.hover or true
		callback(nil, {
			capabilities = server_capabilities,
			serverInfo = {
				name = "npackages_ls",
			},
		})
	end,

	-- Request handlers
	[methods.textDocument_hover] = textDocument.hover,
	[methods.textDocument_codeAction] = textDocument.codeAction,
	[methods.textDocument_diagnostic] = textDocument.diagnostic,
	[methods.textDocument_completion] = textDocument.completion,
	[methods.textDocument_documentSymbol] = textDocument.documentSymbol,
	[methods.textDocument_semanticTokens_full] = textDocument.semanticTokens,
	[methods.textDocument_codeLens] = textDocument.codeLens,
	[methods.textDocument_definition] = textDocument.definition,
	[methods.textDocument_inlayHint] = textDocument.inlayHint,

	-- Notification handlers
	[methods.textDocument_didOpen] = textDocument.didOpen,
	[methods.textDocument_didChange] = textDocument.didChange,
	[methods.textDocument_didClose] = textDocument.didClose,
	[methods.textDocument_didSave] = textDocument.didSave,
}

M.messages = {}

---@class ServerOpts
---@field on_request fun(method: string, params: any)?
---@field on_notify fun(method: string, params: any)?

-- A server implementation is just a function that returns a table with several methods
-- `dispatchers` is a table with a couple methods that allow the server to interact with the client
---@param opts ServerOpts|nil
---@return fun(_: vim.lsp.rpc.Dispatchers): vim.lsp.rpc.PublicClient
function M.server(opts)
	opts = opts or {}
	local on_request = opts.on_request or function(_, _) end
	local on_notify = opts.on_notify or function(_, _) end

	return function(dispatchers)
		local closing = false
		local srv = {}
		local request_id = 0
		state.session.dispatchers = dispatchers

		-- This method is called each time the client makes a request to the server
		-- `method` is the LSP method name
		-- `params` is the payload that the client sends
		-- `callback` is a function which takes two parameters: `err` and `result`
		-- The callback must be called to send a response to the client
		-- To learn more about what method names are available and the structure of
		-- the payloads you'll need to read the specification:
		-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
		---@param method string
		---@param params any
		---@param callback fun(...)
		---@return boolean
		---@return integer
		function srv.request(method, params, callback)
			pcall(on_request, method, params)
			table.insert(M.messages, {
				method = method,
				params = params,
			})
			local handler = handlers[method]
			if handler then
				handler(params, callback)
			end
			request_id = request_id + 1
			return true, request_id
		end

		-- This method is called each time the client sends a notification to the server
		-- The difference between `request` and `notify` is that notifications don't expect a response
		---@param method string
		---@param params any
		function srv.notify(method, params)
			pcall(on_notify, method, params)
			table.insert(M.messages, {
				method = method,
				params = params,
			})
			local handler = handlers[method]
			if handler then
				handler(params, function(_, _)
					if
						method == methods.textDocument_didOpen
						or method == methods.textDocument_didChange
						or method == methods.textDocument_didSave
					then
						local doc = params.textDocument
						nio.run(function()
							workspace.refresh(doc.uri, uuid())
						end, function()
							diagnostic.request_diagnostics(doc.uri, uuid())
							local buf = vim.uri_to_bufnr(doc.uri)
							extmark.clear(buf)
							extmark.display(buf, state.doc_cache[doc.uri].info)
						end)
					end
				end)
			end
			if method == methods.exit then
				dispatchers.on_exit(0, 15)
			end
		end

		-- Indicates if the client is shutting down
		function srv.is_closing()
			return closing
		end

		-- Called when the client wants to terminate the process
		function srv.terminate()
			closing = true
		end

		return srv
	end
end

return M
