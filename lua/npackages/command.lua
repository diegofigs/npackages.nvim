local actions = require("npackages.actions")
local core = require("npackages.core")
local popup = require("npackages.popup")

local M = {}

---@type {[1]: string, [2]: function}[]
local sub_commands = {
	{ "hide", core.hide },
	{ "show", core.show },
	{ "toggle", core.toggle },
	{ "sync", core.update },
	{ "reload", core.reload },

	{ "add", actions.add },
	{ "update", actions.update },
	{ "delete", actions.delete },
	{ "install", actions.install },
	{ "change_version", actions.change_version },

	{ "upgrade_package", actions.upgrade_package },
	{ "upgrade_packages", actions.upgrade_packages },
	{ "upgrade_all_packages", actions.upgrade_all_packages },
	{ "update_package", actions.update_package },
	{ "update_packages", actions.update_packages },
	{ "update_all_packages", actions.update_all_packages },

	{ "open_homepage", actions.open_homepage },
	{ "open_repository", actions.open_repository },
	{ "open_npmjsorg", actions.open_npmjs() },

	{ "popup_available", popup.available },
	{ "show_popup", popup.show },
	{ "show_package_popup", popup.show_package },
	{ "show_versions_popup", popup.show_versions },
	{ "show_dependencies_popup", popup.show_dependencies },
	{ "focus_popup", popup.focus },
	{ "hide_popup", popup.hide },
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
			---@type any
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
