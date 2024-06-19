local npm = require("npackages.lib.npm")
local job = require("npackages.lib.job")
local loading = require("npackages.ui.loading")
local reload = require("npackages.ui.reload")
local state = require("npackages.state")
local util = require("npackages.util")
local scanner = require("npackages.lsp.scanner")

--- Returns the delete command based on package manager
---@param dependency_name string - dependency for which to get the command
---@return string
local function get_command(dependency_name)
	local package_manager = state.package_manager[util.current_buf()]
	if package_manager == npm.PACKAGE_MANAGERS.yarn then
		return "yarn remove " .. dependency_name
	elseif package_manager == npm.PACKAGE_MANAGERS.pnpm then
		return "pnpm remove " .. dependency_name
	else
		return "npm uninstall " .. dependency_name
	end
end

--- Runs the delete action
-- @return nil
return function()
	local current_line = vim.fn.getline(".")

	local dependency_name = scanner.get_dependency_name_from_line(current_line)

	if dependency_name == nil then
		return
	end

	local buf = util.current_buf()
	local cmd = get_command(dependency_name)
	vim.ui.select({ "Confirm", "Cancel" }, {
		prompt = "Run `" .. cmd .. "`",
	}, function(choice)
		if choice == "Confirm" then
			local id = loading.new("|  Deleting " .. dependency_name .. " dependency")
			job({
				command = cmd,
				on_start = function()
					loading.start(id)
				end,
				on_success = function()
					loading.stop(id)
					reload(buf)
				end,
				on_error = function()
					loading.stop(id)
				end,
				output = true,
			})
		end
	end)
end
