local npm = require("npackages.npm")
local job = require("npackages.util.job")
local loading = require("npackages.ui.loading")
local state = require("npackages.state")
local util = require("npackages.util")

--- Returns the install command based on package manager
---@return string
local function get_command()
	local package_manager = state.package_manager[util.current_buf()]
	if package_manager == npm.PACKAGE_MANAGERS.yarn then
		if state.has_old_yarn then
			return "yarn install"
		end

		return "yarn install"
	elseif package_manager == npm.PACKAGE_MANAGERS.pnpm then
		return "pnpm install"
	else
		return "npm install"
	end
end

--- Runs the install action
-- @return nil
return function()
	local cmd = get_command()

	vim.ui.select({ "Confirm", "Cancel" }, {
		prompt = "Run `" .. cmd .. "`",
	}, function(choice)
		if choice == "Confirm" then
			local id = loading.new("| 󰑓 Syncing dependencies")
			job({
				json = false,
				command = cmd,
				on_start = function()
					loading.start(id)
				end,
				on_success = function()
					loading.stop(id)
				end,
				on_error = function()
					loading.stop(id)
				end,
			})
		end
	end)
end
