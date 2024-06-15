local server = require("npackages.lsp.server")
local lsp_state = require("npackages.lsp.state")
local state = require("npackages.state")
local util = require("npackages.util")
local logger = require("npackages.logger")

local M = {}

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

function M.start()
	local commands = {
		---@param cmd lsp.Command
		open_url = function(cmd)
			local url = cmd.arguments[1]
			if url and type(url) == "string" then
				util.open_url(url)
			end
		end,
	}

	local client_id = vim.lsp.start({
		name = state.cfg.lsp.name,
		cmd = server(),
		root_dir = vim.fs.root(0, { "package.json" }),
		filetypes = { "json" },
		autostart = state.cfg.autoload,
		commands = commands,
		on_init = function(client, _)
			lsp_state.session.client_id = client.id
		end,
		on_attach = function(client, bufnr)
			state.cfg.lsp.on_attach(client, bufnr)
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

	if client_id then
		return client_id
	else
		return
	end
end

return M
