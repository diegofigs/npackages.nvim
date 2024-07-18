local nio = require("nio")
local add = require("npackages.command.add")
local update = require("npackages.command.update")
local delete = require("npackages.command.delete")
local install = require("npackages.command.install")
local change_version = require("npackages.command.change_version")
local workspace = require("npackages.lsp.workspace")
local client = require("npackages.lsp.client")
local progress = require("npackages.lsp.progress")
local lsp = require("npackages.lsp.state")
local uuid = require("npackages.lib.uuid")
local state = require("npackages.state")
local extmark = require("npackages.ui.extmark")
local hover = require("npackages.hover")
local util = require("npackages.util")

local M = {}

function M.hide()
	state.visible = false
	for uri, _ in pairs(lsp.doc_cache) do
		local b = vim.uri_to_bufnr(uri)
		if b then
			extmark.clear(b)
		end
	end
end

function M.show()
	state.visible = true
	for uri, doc_cache in pairs(lsp.doc_cache) do
		local b = vim.uri_to_bufnr(uri)
		if b then
			extmark.display(b, doc_cache.info)
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
	local uri = vim.uri_from_bufnr(buf)
	nio.run(function()
		workspace.refresh(uri)
		nio.scheduler()
		client.request_diagnostics(uri, uuid())
		extmark.display(buf, lsp.doc_cache[uri].info)
	end)
end

function M.reload()
	local buf = util.current_buf()
	local uri = vim.uri_from_bufnr(buf)

	local wdt = uuid()
	progress.begin(wdt, "Indexing")
	nio.run(function()
		workspace.reload(uri, wdt)
		nio.scheduler()
		client.request_diagnostics(uri)
		extmark.display(buf, lsp.doc_cache[uri].info)
	end, function(_)
		progress.finish(wdt)
	end)
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
