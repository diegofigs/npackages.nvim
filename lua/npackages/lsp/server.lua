local codeAction = require("npackages.lsp.codeAction")
local completion = require("npackages.lsp.completion")
local textDocument = require("npackages.lsp.textDocument")
local logger = require("npackages.logger")
local state = require("npackages.state")
local lsp_state = require("npackages.lsp.state")
local hover = require("npackages.hover")

---@type lsp.ServerCapabilities
local server_capabilities = {
	textDocumentSync = {
		change = 1,
		openClose = true,
	},
	codeActionProvider = state.cfg.lsp.actions,
	completionProvider = (state.cfg.lsp.completion or {}) and {
		triggerCharacters = completion.trigger_characters,
	},
	diagnosticProvider = {
		workDoneProgress = true,
		workspaceDiagnostics = true,
		interFileDependencies = false,
	},
	hoverProvider = state.cfg.lsp.hover,
}

local handlers = {
	---@param method string
	---@param params lsp.InitializeParams
	---@param callback fun(err: nil, result: lsp.InitializeResult)
	[vim.lsp.protocol.Methods.initialize] = function(method, params, callback)
		lsp_state.wdt_cache[params.rootUri] = params.workDoneToken
		callback(nil, {
			capabilities = server_capabilities,
			serverInfo = {
				name = "npackages_ls",
			},
		})
	end,

	---@param method string
	---@param params lsp.CodeActionParams
	---@param callback fun(err: nil, actions: lsp.CodeAction[])
	[vim.lsp.protocol.Methods.textDocument_codeAction] = function(method, params, callback)
		callback(nil, codeAction.get(params))
	end,

	---@param method string
	---@param params lsp.CompletionParams
	---@param callback fun(err: nil, items: lsp.CompletionList|nil)
	[vim.lsp.protocol.Methods.textDocument_completion] = function(method, params, callback)
		completion.complete(params, function(response)
			callback(nil, response)
		end)
	end,

	---@param method string
	---@param params lsp.HoverParams
	---@param callback fun(err: nil, result: lsp.Hover)
	[vim.lsp.protocol.Methods.textDocument_hover] = function(method, params, callback)
		hover.show()
		-- callback(nil, textDocument.hover(params))
	end,

	---@param method string
	---@param params lsp.DocumentDiagnosticParams
	---@param callback fun(err: nil, result: lsp.DocumentDiagnosticReport)
	[vim.lsp.protocol.Methods.textDocument_diagnostic] = function(method, params, callback)
		textDocument.diagnostic(params, function(result)
			callback(nil, result)
		end)
	end,

	---@param method string
	---@param params lsp.WorkspaceDiagnosticParams
	---@param callback fun(err: nil, result: lsp.WorkspaceDocumentDiagnosticReport)
	[vim.lsp.protocol.Methods.workspace_diagnostic] = function(method, params, callback)
		logger.info(params)
	end,

	---@param method string
	---@param params lsp.WorkspaceDiagnosticParams
	---@param callback fun(err: nil, result: lsp.WorkspaceDocumentDiagnosticReport)
	[vim.lsp.protocol.Methods.workspace_diagnostic_refresh] = function(method, params, callback)
		logger.info(params)
	end,

	[vim.lsp.protocol.Methods.shutdown] = function(_, _, callback)
		callback(nil, nil)
	end,
}

local notify_handlers = {
	[vim.lsp.protocol.Methods.textDocument_didOpen] = textDocument.didOpen,
	[vim.lsp.protocol.Methods.textDocument_didChange] = textDocument.didChange,
	[vim.lsp.protocol.Methods.textDocument_didClose] = textDocument.didClose,
}

---@class ServerOpts
---@field on_request fun(method: string, params: any)?
---@field on_notify fun(method: string, params: any)?

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

		---@param method string
		---@param params any
		---@param callback fun(...)
		---@return boolean
		---@return integer
		function srv.request(method, params, callback)
			pcall(on_request, method, params)
			local handler = handlers[method]
			if handler then
				handler(method, params, callback)
			end
			request_id = request_id + 1
			return true, request_id
		end

		---@param method string
		---@param params any
		function srv.notify(method, params)
			pcall(on_notify, method, params)
			local handler = notify_handlers[method]
			if handler then
				handler(params, function(diagnostics) end)
			end
			if method == "exit" then
				dispatchers.on_exit(0, 15)
			end
		end

		---@return boolean
		function srv.is_closing()
			return closing
		end

		function srv.terminate()
			closing = true
		end

		return srv
	end
end

return server
