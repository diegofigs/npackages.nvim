local lsp_state = require("npackages.lsp.state")
local plugin = require("npackages.state")
local util = require("npackages.util")
local logger = require("npackages.logger")

local M = {}

---@param uri lsp.DocumentUri
---@param workDoneToken lsp.ProgressToken?
M.request_diagnostics = function(uri, workDoneToken)
	local client_id = lsp_state.session.client_id

	if client_id then
		local client = vim.lsp.get_client_by_id(client_id)
		if client then
			---@type lsp.DocumentDiagnosticParams
			local diagnostic_params = {
				textDocument = { uri = uri },
				workDoneToken = workDoneToken,
			}
			return client.request(vim.lsp.protocol.Methods.textDocument_diagnostic, diagnostic_params)
		end
	end
end

---@param request_id string|integer
M.cancel_request = function(request_id)
	local client_id = lsp_state.session.client_id

	if client_id then
		local client = vim.lsp.get_client_by_id(client_id)
		if client then
			---@type lsp.CancelParams
			local cancel_params = {
				id = request_id,
			}
			return client.request(vim.lsp.protocol.Methods.dollar_cancelRequest, cancel_params)
		end
	end
end

-- The default Neovim reuse_client function checks root_dir,
-- which is not used or needed by our LSP client.
--
-- So just check the client name.
--
--- @param client vim.lsp.Client
--- @param config vim.lsp.ClientConfig
--- @return boolean
local function reuse_client(client, config)
	return client.name == config.name
end

function M.start(server)
	local client_id = vim.lsp.start({
		name = plugin.cfg.lsp.name,
		cmd = server(),
		root_dir = vim.fs.root(0, { "package.json" }),
		filetypes = { "json" },
		autostart = plugin.cfg.autoload,
		init_options = {
			codeAction = plugin.cfg.lsp.actions,
			completion = plugin.cfg.lsp.completion,
			hover = plugin.cfg.lsp.hover,
		},
		commands = {
			open_url = function(cmd)
				local url = cmd.arguments[1]
				if url and type(url) == "string" then
					util.open_url(url)
				end
			end,
			run_script = function(cmd)
				local script_name = cmd.arguments[1]
				local uri = cmd.arguments[2]
				if script_name and type(script_name) == "string" and uri and type(uri) == "string" then
					util.run_script(script_name, uri)
				end
			end,
		},
		on_init = function(client, _)
			lsp_state.session.client_id = client.id
		end,
		on_attach = function(client, bufnr)
			plugin.cfg.lsp.on_attach(client, bufnr)
		end,
		on_error = function(code, err)
			logger.error({ code = code, err = err })
		end,
		on_exit = function(code, signal, client_id)
			logger.trace({ code = code, signal = signal, client_id = client_id })
		end,
	}, {
		bufnr = util.current_buf(),
		reuse_client = reuse_client,
		silent = false,
	})

	return client_id
end

return M
