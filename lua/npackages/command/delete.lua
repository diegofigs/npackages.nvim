local npm = require("npackages.npm")
local job = require("npackages.util.job")
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
