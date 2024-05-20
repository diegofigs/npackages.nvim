local constants = require("npackages.constants")
local job = require("npackages.utils.job")
local reload = require("npackages.utils.reload")
local state = require("npackages.state")
local util = require("npackages.util")
local loading = require("npackages.ui.loading")

--- Returns the install command based on package manager
---@param dependency_name string - dependency for which to get the command
---@param type string - package manager for which to get the command
---@return string
local function get_command(type, dependency_name)
	local package_manager = state.package_manager[util.current_buf()]
	if type == constants.DEPENDENCY_TYPE.development then
		if package_manager == constants.PACKAGE_MANAGERS.yarn then
			return "yarn add -D " .. dependency_name
		elseif package_manager == constants.PACKAGE_MANAGERS.pnpm then
			return "pnpm add -D " .. dependency_name
		else
			return "npm install --save-dev " .. dependency_name
		end
	else
		if package_manager == constants.PACKAGE_MANAGERS.yarn then
			return "yarn add " .. dependency_name
		elseif package_manager == constants.PACKAGE_MANAGERS.pnpm then
			return "pnpm add " .. dependency_name
		else
			return "npm install " .. dependency_name
		end
	end
end

--- Runs the install new dependency action
-- @return nil
return function()
	vim.ui.select({ "Production", "Development", "Cancel" }, {
		prompt = "Select Dependency Type",
		---@param selected_dependency_type string|nil
	}, function(selected_dependency_type)
		if selected_dependency_type ~= "Cancel" or selected_dependency_type ~= nil then
			vim.ui.input({
				prompt = "Enter Dependency Name",
			}, function(dependency_name)
				local id = loading.new("| 󰇚 Installing " .. dependency_name .. " dependency")
				local type = constants.DEPENDENCY_TYPE[selected_dependency_type:lower()]
				job({
					json = false,
					command = get_command(type, dependency_name),
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
			end)
		end
	end)
end
