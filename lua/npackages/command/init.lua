local add = require("npackages.command.add")
local update = require("npackages.command.update")
local delete = require("npackages.command.delete")
local install = require("npackages.command.install")
local change_version = require("npackages.command.change_version")
local core = require("npackages.lsp.core")
local lsp_state = require("npackages.lsp.state")
local state = require("npackages.state")
local ui = require("npackages.ui")
local hover = require("npackages.hover")
local util = require("npackages.util")

local M = {}

function M.hide()
	state.visible = false
	for uri, _ in pairs(lsp_state.doc_cache) do
		local b = vim.uri_to_bufnr(uri)
		if b then
			ui.clear(b)
		end
	end
end

function M.show()
	state.visible = true

	for uri, _ in pairs(lsp_state.doc_cache) do
		local b = vim.uri_to_bufnr(uri)
		if b then
			-- TODO: do not trigger update when showing
			M.update()
		end
	end
end

function M.toggle()
	if state.visible then
		M.hide()
	else
		M.show()
	end
end

function M.update()
	local buf = util.current_buf()
	core.update(vim.uri_from_bufnr(buf))
end

function M.reload()
	local buf = util.current_buf()
	core.reload(vim.uri_from_bufnr(buf))
end

local sub_commands = {
	{ "hide", M.hide },
	{ "show", M.show },
	{ "toggle", M.toggle },
	{ "refresh", M.update },
	{ "reload", M.reload },

	{ "add", add },
	{ "update", update },
	{ "delete", delete },
	{ "install", install },
	{ "change_version", change_version },

	-- { "upgrade_package", actions.upgrade_package },
	-- { "upgrade_packages", actions.upgrade_packages },
	-- { "upgrade_all_packages", actions.upgrade_all_packages },
	-- { "update_package", actions.update_package },
	-- { "update_packages", actions.update_packages },
	-- { "update_all_packages", actions.update_all_packages },
	--
	-- { "open_homepage", actions.open_homepage },
	-- { "open_repository", actions.open_repository },
	-- { "open_npmjsorg", actions.open_npmjs() },

	{ "hover_available", hover.available },
	{ "hover", hover.show },
	{ "hover_package", hover.show_package },
	{ "hover_version", hover.show_versions },
	-- { "hover_deps", hover.show_dependencies },
	{ "hover_focus", hover.focus },
	{ "hover_hide", hover.hide },
}

---@param arglead string
---@param line string
---@return string[]
local function complete(arglead, line)
	local matches = {}

	local words = vim.split(line, "%s+")
	if #words > 2 then
		return matches
	end

	for _, s in ipairs(sub_commands) do
		if vim.startswith(s[1], arglead) then
			table.insert(matches, s[1])
		end
	end
	return matches
end

---@param cmd table<string,any>
local function exec(cmd)
	for _, s in ipairs(sub_commands) do
		if s[1] == cmd.args then
			local fn = s[2]
			local ret = fn()
			if ret ~= nil then
				print(vim.inspect(ret))
			end
			return
		end
	end

	print(string.format('unknown sub command "%s"', cmd.args))
end

function M.create_commands()
	vim.api.nvim_create_user_command("Npackages", exec, {
		nargs = 1,
		range = true,
		complete = complete,
	})
end

return M
