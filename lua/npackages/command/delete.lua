local constants = require("npackages.constants")
local get_dependency_name_from_current_line = require("npackages.utils.get_dependency_name_from_current_line")
local job = require("npackages.utils.job")
local loading = require("npackages.ui.loading")
local reload = require("npackages.utils.reload")
local state = require("npackages.state")
local util = require("npackages.util")

--- Returns the delete command based on package manager
---@param dependency_name string - dependency for which to get the command
---@return string
local function get_command(dependency_name)
	local package_manager = state.package_manager[util.current_buf()]
	if package_manager == constants.PACKAGE_MANAGERS.yarn then
		return "yarn remove " .. dependency_name
	elseif package_manager == constants.PACKAGE_MANAGERS.pnpm then
		return "pnpm remove " .. dependency_name
	else
		return "npm uninstall " .. dependency_name
	end
end

--- Runs the delete action
-- @return nil
return function()
	local dependency_name = get_dependency_name_from_current_line()

	if dependency_name == nil then
		return
	end

	local cmd = get_command(dependency_name)
	vim.ui.select({ "Confirm", "Cancel" }, {
		prompt = "Run `" .. cmd .. "`",
	}, function(choice)
		if choice == "Confirm" then
			local id = loading.new("|  Deleting " .. dependency_name .. " dependency")
			job({
				json = false,
				command = cmd,
				on_start = function()
					loading.start(id)
				end,
				on_success = function()
					loading.stop(id)
					reload()
				end,
				on_error = function()
					loading.stop(id)
				end,
			})
		end
	end)
end
