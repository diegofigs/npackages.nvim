local npm = require("npackages.lib.npm")
local job = require("npackages.lib.job")
local reload = require("npackages.ui.reload")
local state = require("npackages.state")
local util = require("npackages.util")
local loading = require("npackages.ui.loading")
local nio = require("nio")

local DEPENDENCY_TYPE = {
	production = "prod",
	development = "dev",
}

--- Returns the install command based on package manager
---@param dependency_name string - dependency for which to get the command
---@param type string - package manager for which to get the command
---@return string
local function get_command(type, dependency_name)
	local package_manager = state.package_manager[util.current_buf()]
	if type == DEPENDENCY_TYPE.development then
		if package_manager == npm.PACKAGE_MANAGERS.yarn then
			return "yarn add -D " .. dependency_name
		elseif package_manager == npm.PACKAGE_MANAGERS.pnpm then
			return "pnpm add -D " .. dependency_name
		else
			return "npm install --save-dev " .. dependency_name
		end
	else
		if package_manager == npm.PACKAGE_MANAGERS.yarn then
			return "yarn add " .. dependency_name
		elseif package_manager == npm.PACKAGE_MANAGERS.pnpm then
			return "pnpm add " .. dependency_name
		else
			return "npm install " .. dependency_name
		end
	end
end

local buf = util.current_buf()
--- Runs the install new dependency action
-- @return nil
return function()
	nio.run(function()
		local selected_dependency_type = nio.ui.select({ "Production", "Development", "Cancel" }, {
			prompt = "Select Dependency Type",
		})

		if selected_dependency_type == "Production" or selected_dependency_type == "Development" then
			---@diagnostic disable-next-line: missing-fields
			local dependency_name = nio.ui.input({
				prompt = "Enter Dependency Name",
			})

			if dependency_name ~= "" and dependency_name ~= nil then
				local id = loading.new("| 󰇚 Installing " .. dependency_name .. " dependency")
				local type = DEPENDENCY_TYPE[selected_dependency_type:lower()]
				job({
					command = get_command(type, dependency_name),
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
		end
	end, nil)
end
