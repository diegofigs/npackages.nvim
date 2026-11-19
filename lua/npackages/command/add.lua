local npm = require("npackages.lib.npm")
local job = require("npackages.lib.job")
local reload = require("npackages.ui.reload")
local state = require("npackages.state")
local util = require("npackages.util")
local loading = require("npackages.ui.loading")
local nio = require("nio")
local input = require("npackages.ui.input")

local DEPENDENCY_TYPE = {
	production = "prod",
	development = "dev",
}

--- Returns the install command based on package manager
---@param dependency_name string - dependency for which to get the command
---@param dependency_type string
---@param package_manager string?
---@return string
local function get_command(dependency_type, dependency_name, package_manager)
	if dependency_type == DEPENDENCY_TYPE.development then
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

--- Runs the install new dependency action
-- @return nil
return function()
	local buf = util.current_buf()
	local package_manager = state.package_manager[buf]
	local cwd = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":h")
	nio.run(function()
		local selected_dependency_type = nio.ui.select({ "Production", "Development", "Cancel" }, {
			prompt = "Select Dependency Type",
		})

		if selected_dependency_type == "Production" or selected_dependency_type == "Development" then
			-- Let the selection UI finish closing before opening the input UI.
			nio.scheduler()
			---@diagnostic disable-next-line: missing-fields
			local dependency_name = input({
				prompt = "Enter Dependency Name",
			})

			if dependency_name == nil then
				return
			end
			dependency_name = vim.trim(dependency_name)
			if dependency_name == "" then
				return
			end
			if dependency_name:find("[%s%c]") or dependency_name:sub(1, 1) == "-" then
				vim.notify(
					"Enter one package name, optionally followed by @version; whitespace and options are not allowed.",
					vim.log.levels.WARN
				)
				return
			end

			if dependency_name ~= "" then
				local id = loading.new("| 󰇚 Installing " .. dependency_name .. " dependency")
				local dependency_type = DEPENDENCY_TYPE[selected_dependency_type:lower()]
				job({
					command = get_command(dependency_type, vim.fn.shellescape(dependency_name), package_manager),
					cwd = cwd,
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
