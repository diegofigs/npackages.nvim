local server = require("npackages.lsp.server")
local state = require("npackages.state")
local util = require("npackages.util")
local logger = require("npackages.logger")

local M = {
	id = nil,
}

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
	local NPACKAGES = "npackages"

	local commands = {
		---@param cmd lsp.Command
		---@param ctx lsp.HandlerContext
		[NPACKAGES] = function(cmd, ctx)
			local action = cmd.arguments[1]
			if action then
				vim.api.nvim_buf_call(ctx.bufnr, action)
			else
				util.notify(vim.log.levels.INFO, "Action not available")
			end
		end,
	}

	---@type integer?
	local client_id = vim.lsp.start({
		name = state.cfg.lsp.name,
		cmd = server(),
		filetypes = { "json" },
		commands = commands,
		autostart = state.cfg.autoload,
		on_attach = state.cfg.lsp.on_attach,
		on_error = function(code, err)
			logger.error({ code = code, err = err })
		end,
	}, {
		bufnr = util.current_buf(),
		reuse_client = reuse_client,
		silent = false,
	})

	if client_id then
		M.id = client_id
	else
		return
	end

	local client = vim.lsp.get_client_by_id(client_id)
	if not client then
		return
	end
end

return M
