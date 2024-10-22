local command = require("npackages.command")
---@diagnostic disable-next-line: different-requires
local config = require("npackages.config.internal")
local highlight = require("npackages.highlight")
local npm = require("npackages.lib.npm")
local state = require("npackages.state")
local util = require("npackages.util")

local M = {}

local function attach()
	npm.parse()
	state.cfg.on_attach(util.current_buf())
end

--- Take all user options and setup the config, source of options is purposefully abstracted
---@param user_options npackages.UserConfig|nil all options user can provide in the plugin config
---@return nil
M.setup = function(user_options)
	-- Configuration
	state.cfg = config.build(vim.g.npackages or user_options)
	state.visible = state.cfg.autostart

	-- Initialization
	command.create_commands()
	highlight.create_highlights()

	local group = vim.api.nvim_create_augroup("Npackages", {})

	if state.cfg.autoload then
		attach()

		vim.api.nvim_create_autocmd("BufRead", {
			group = group,
			pattern = "package.json",
			callback = attach,
		})
	end

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		pattern = "package.json",
		callback = function()
			require("npackages.hover").hide()
		end,
	})
end

return M
