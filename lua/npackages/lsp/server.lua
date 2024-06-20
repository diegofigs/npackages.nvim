local state = require("npackages.lsp.state")
local textDocument = require("npackages.lsp.textDocument")
local completion = require("npackages.lsp.textDocument.completion")
local logger = require("npackages.logger")

---@type lsp.ServerCapabilities
local server_capabilities = {
	textDocumentSync = {
		change = 1,
		openClose = true,
		save = true,
	},
	diagnosticProvider = {
		workDoneProgress = true,
		workspaceDiagnostics = false,
		interFileDependencies = false,
	},
}

local handlers = {
	---@param params lsp.InitializeParams
	---@param callback fun(err: nil, result: lsp.InitializeResult)
	[vim.lsp.protocol.Methods.initialize] = function(params, callback)
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
	[vim.lsp.protocol.Methods.textDocument_hover] = textDocument.hover,
	[vim.lsp.protocol.Methods.textDocument_codeAction] = textDocument.codeAction,
	[vim.lsp.protocol.Methods.textDocument_diagnostic] = textDocument.diagnostic,
	[vim.lsp.protocol.Methods.textDocument_completion] = textDocument.completion,

	-- Notification handlers
	[vim.lsp.protocol.Methods.textDocument_didOpen] = textDocument.didOpen,
	[vim.lsp.protocol.Methods.textDocument_didChange] = textDocument.didChange,
	[vim.lsp.protocol.Methods.textDocument_didClose] = textDocument.didClose,
	[vim.lsp.protocol.Methods.textDocument_didSave] = textDocument.didSave,
}

local random = math.random
local function uuid()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
		return string.format("%x", v)
	end)
end

local request_diagnostics = function(uri, wdt)
	local client_id = state.session.client_id

	if client_id then
		local client = vim.lsp.get_client_by_id(client_id)
		if client then
			---@type lsp.DocumentDiagnosticParams
			local diagnostic_params = {
				textDocument = { uri = uri },
				workDoneToken = wdt,
			}
			client.request(vim.lsp.protocol.Methods.textDocument_diagnostic, diagnostic_params)
		end
	end
end

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
			logger.debug(method)
			logger.debug(params)
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
			logger.debug(method)
			logger.debug(params)
			local handler = handlers[method]
			if handler then
				handler(params, function(_, _)
					if
						method == vim.lsp.protocol.Methods.textDocument_didOpen
						or method == vim.lsp.protocol.Methods.textDocument_didChange
					then
						local doc = params.textDocument
						request_diagnostics(doc.uri, uuid())

					end
				end)
			end
			if method == vim.lsp.protocol.Methods.exit then
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
