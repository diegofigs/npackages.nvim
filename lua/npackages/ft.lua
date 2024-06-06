local async = require("npackages.async")
local command = require("npackages.command")
---@diagnostic disable-next-line: different-requires
local config = require("npackages.config.internal")
local core = require("npackages.core")
local highlight = require("npackages.highlight")
local npm = require("npackages.npm")
local popup = require("npackages.popup")
local state = require("npackages.state")
local util = require("npackages.util")

local M = {}

local function extend_triggers()
	if state.cfg.completion.npackages.enabled then
		local triggers = require("npackages.completion.common").trigger_characters
		for _, v in ipairs({
			"a",
			"b",
			"c",
			"d",
			"e",
			"f",
			"g",
			"h",
			"i",
			"j",
			"k",
			"l",
			"m",
			"n",
			"o",
			"p",
			"q",
			"r",
			"s",
			"t",
			"u",
			"v",
			"w",
			"x",
			"y",
			"z",
			"-",
			"_",
		}) do
			triggers[#triggers + 1] = v
		end
	end
end

local function attach()
	if state.cfg.completion.cmp.enabled then
		extend_triggers()
		require("npackages.completion.cmp").setup()
	end

	if state.cfg.lsp.enabled then
		extend_triggers()
		require("npackages.lsp").start()
	end

	npm.parse()
	core.update()
	state.cfg.on_attach(util.current_buf())
end

--- Take all user options and setup the config, source of options is purposefully abstracted
---@param user_options table|nil all options user can provide in the plugin config
---@return nil
M.setup = function(user_options)
	-- Configuration
	state.cfg = config.build(vim.g.npackages or user_options)
	state.visible = state.cfg.autostart

	-- Initialization
	command.create_commands()
	highlight.create_highlights()

	local group = vim.api.nvim_create_augroup("NpackagesAutogroup", {})

	if state.cfg.autoload then
		attach()

		vim.api.nvim_create_autocmd("BufRead", {
			group = group,
			pattern = "package.json",
			callback = attach,
		})
	end

	-- initialize the throttled update function with timeout
	core.inner_throttled_update = async.throttle(core.update, state.cfg.autoupdate_throttle)

	if state.cfg.autoupdate then
		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
			group = group,
			pattern = "package.json",
			callback = function()
				core.throttled_update(nil, false)
			end,
		})

		vim.api.nvim_create_autocmd("BufWritePost", {
			group = group,
			pattern = "package.json",
			callback = function()
				core.update()
			end,
		})
	end

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		pattern = "package.json",
		callback = popup.hide,
	})
end

return M
