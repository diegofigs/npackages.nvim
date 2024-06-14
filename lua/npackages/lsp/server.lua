local codeAction = require("npackages.lsp.codeAction")
local completion = require("npackages.lsp.completion")
local textDocument = require("npackages.lsp.textDocument")
local logger = require("npackages.logger")
local plugin = require("npackages.state")
local state = require("npackages.lsp.state")

---@type lsp.ServerCapabilities
local server_capabilities = {
	textDocumentSync = {
		change = 1,
		openClose = true,
		save = false, -- TODO: enable textDocument/didSave
	},
	codeActionProvider = plugin.cfg.lsp.actions,
	completionProvider = (plugin.cfg.lsp.completion or {}) and {
		triggerCharacters = completion.trigger_characters,
	},
	hoverProvider = plugin.cfg.lsp.hover,
	diagnosticProvider = {
		workspaceDiagnostics = false,
		interFileDependencies = false,
	},
}

local handlers = {
	---@param method string
	---@param params lsp.InitializeParams
	---@param callback fun(err: nil, result: lsp.InitializeResult)
	[vim.lsp.protocol.Methods.initialize] = function(method, params, callback)
		state.wdt_cache[params.rootUri] = params.workDoneToken
		callback(nil, {
			capabilities = server_capabilities,
			serverInfo = {
				name = "npackages_ls",
			},
		})
	end,

	---@param method string
	---@param params lsp.CodeActionParams
	---@param callback fun(err: nil, actions: lsp.CodeAction[]|nil)
	[vim.lsp.protocol.Methods.textDocument_codeAction] = function(method, params, callback)
		callback(nil, codeAction.get(params))
	end,

	---@param method string
	---@param params lsp.CompletionParams
	---@param callback fun(err: nil, result: vim.lsp.CompletionResult|nil)
	[vim.lsp.protocol.Methods.textDocument_completion] = function(method, params, callback)
		completion.complete(params, function(result)
			callback(nil, result)
		end)
	end,

	---@param method string
	---@param params lsp.HoverParams
	---@param callback fun(err: nil, result: lsp.Hover|nil)
	[vim.lsp.protocol.Methods.textDocument_hover] = function(method, params, callback)
		callback(nil, textDocument.hover(params))
	end,

	---@param method string
	---@param params lsp.DocumentDiagnosticParams
	---@param callback fun(err: nil, result: lsp.DocumentDiagnosticReport)
	[vim.lsp.protocol.Methods.textDocument_diagnostic] = function(method, params, callback)
		textDocument.diagnostic(params, function(result)
			-- local doc = params.textDocument
			-- local buf = vim.uri_to_bufnr(doc.uri)
			--
			-- local session = state.session[buf]
			--
			-- if session then
			-- 	local client_id = session.client_id
			-- 	vim.lsp.diagnostic.on_diagnostic(
			-- 		nil,
			-- 		result,
			-- 		{ client_id = client_id, bufnr = buf, method = method },
			-- 		{}
			-- 	)
			-- end
			callback(nil, result)
		end)
	end,

	------@param method string
	------@param params lsp.WorkspaceDiagnosticParams
	------@param callback fun(err: nil, result: lsp.WorkspaceDocumentDiagnosticReport)
	---[vim.lsp.protocol.Methods.workspace_diagnostic] = function(method, params, callback)
	---	logger.info(params)
	---end,
	---
	------@param method string
	------@param params lsp.WorkspaceDiagnosticParams
	------@param callback fun(err: nil, result: lsp.WorkspaceDocumentDiagnosticReport)
	---[vim.lsp.protocol.Methods.workspace_diagnostic_refresh] = function(method, params, callback)
	---	logger.info(params)
	---end,

	[vim.lsp.protocol.Methods.shutdown] = function(_, _, callback)
		callback(nil, nil)
	end,
}

local notify_handlers = {
	---@param params lsp.DidOpenTextDocumentParams
	[vim.lsp.protocol.Methods.textDocument_didOpen] = function(params, callback)
		textDocument.didOpen(params, function(result)
			callback(nil, result)
		end)
	end,
	---@param params lsp.DidChangeTextDocumentParams
	[vim.lsp.protocol.Methods.textDocument_didChange] = function(params, callback)
		textDocument.didChange(params, function(result)
			callback(nil, result)
		end)
	end,
	---@param params lsp.DidCloseTextDocumentParams
	[vim.lsp.protocol.Methods.textDocument_didClose] = function(params, callback)
		textDocument.didClose(params)
		callback(nil, nil)
	end,
	[vim.lsp.protocol.Methods.textDocument_didSave] = textDocument.didSave,
}

---@class ServerOpts
---@field on_request fun(method: string, params: any)?
---@field on_notify fun(method: string, params: any)?

-- A server implementation is just a function that returns a table with several methods
-- `dispatchers` is a table with a couple methods that allow the server to interact with the client
---@param opts ServerOpts|nil
---@return fun(_: vim.lsp.rpc.Dispatchers): vim.lsp.rpc.PublicClient
local function server(opts)
	opts = opts or {}
	local on_request = opts.on_request or function(_, _) end
	local on_notify = opts.on_notify or function(_, _) end

	return function(dispatchers)
		local closing = false
		local srv = {}
		local request_id = 0
		-- state.session.dispatchers = dispatchers

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
			logger.debug(method)
			logger.debug(params)
			local handler = handlers[method]
			if handler then
				handler(method, params, callback)
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
			local handler = notify_handlers[method]
			logger.debug(method)
			logger.debug(params)
			if handler then
				handler(params, function(diagnostics)
					if diagnostics then
						dispatchers.server_request(vim.lsp.protocol.Methods.textDocument_publishDiagnostics, {
							uri = params.textDocument.uri,
							version = params.textDocument.version,
							diagnostics = diagnostics,
						})
					end
				end)
			end
			if method == "exit" then
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

return server
