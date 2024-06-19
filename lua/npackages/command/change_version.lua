local npm = require("npackages.lib.npm")
local job = require("npackages.lib.job")
local loading = require("npackages.ui.loading")
local reload = require("npackages.ui.reload")
local state = require("npackages.state")
local util = require("npackages.util")
local scanner = require("npackages.lsp.scanner")
local nio = require("nio")

--- Returns the change version command based on package manager
---@param dependency_name string dependency for which to get the command
---@param version string used to denote the version to be installed
---@param package_manager string
---@return string
local function get_change_version_command(dependency_name, version, package_manager)
	if package_manager == npm.PACKAGE_MANAGERS.yarn then
		if state.has_old_yarn then
			return "yarn upgrade " .. dependency_name .. "@" .. version
		end

		return "yarn up " .. dependency_name .. "@" .. version
	elseif package_manager == npm.PACKAGE_MANAGERS.pnpm then
		return "pnpm add " .. dependency_name .. "@" .. version
	else
		return "npm install " .. dependency_name .. "@" .. version
	end
end

--- Returns available package versions command based on package manager
---@param dependency_name string dependency for which to get the command
---@param package_manager string
---@return string
local function get_version_list_command(dependency_name, package_manager)
	if package_manager == npm.PACKAGE_MANAGERS.pnpm then
		return "pnpm view " .. dependency_name .. " versions --json"
	else
		return "npm view " .. dependency_name .. " versions --json"
	end
end

--- Maps output from api to sorted versions in desc order
---@param versions string[] versions to map to menu items
---@return string[] version_list mapped to menu items
local function create_select_items(versions)
	local version_list = {}

	-- Iterate versions from the end to show the latest versions first
	for index = #versions, 1, -1 do
		local version = versions[index]
		local is_unstable = string.match(version, "-")

		-- TODO: Option to skip unstable version e.g next@11.1.0-canary
		if not is_unstable then
			table.insert(version_list, version)
			-- else
			-- 	table.insert(version_list, version)
		end
	end

	return version_list
end

--- Runs the change version action
-- @return nil
return function()
	local current_line = vim.fn.getline(".")

	local dependency_name = scanner.get_dependency_name_from_line(current_line)

	if not dependency_name then
		return
	end

	local id = loading.new("| 󰇚 Fetching " .. dependency_name .. " versions")

	local package_manager = state.package_manager[util.current_buf()]
	local buf = util.current_buf()

	nio.run(function()
		loading.start(id)
		local npm_versions_cmd = get_version_list_command(dependency_name, package_manager)
		local npm_versions_args = vim.split(npm_versions_cmd, " ")
		local versions_cmd = table.remove(npm_versions_args, 1)
		local versions_args = npm_versions_args

		local process = nio.process.run({
			cmd = versions_cmd,
			args = versions_args,
		})
		if process then
			local output = process.stdout.read()
			process.close()
			loading.stop(id)

			local ok, versions = pcall(nio.fn.json_decode, output)

			if not ok then
				return
			end

			local selected_version = nio.ui.select(create_select_items(versions), {
				prompt = "Change version of `" .. dependency_name .. "`",
			})

			if selected_version ~= "" and selected_version ~= nil then
				local change_id = loading.new("| 󰇚 Installing " .. dependency_name .. "@" .. selected_version)

				job({
					command = get_change_version_command(dependency_name, selected_version, package_manager),
					on_start = function()
						loading.start(change_id)
					end,
					on_success = function()
						loading.stop(change_id)
						reload(buf)
					end,
					on_error = function()
						loading.stop(change_id)
					end,
					output = true,
				})
			end
		else
			loading.stop(id)
		end
	end, nil)
end
