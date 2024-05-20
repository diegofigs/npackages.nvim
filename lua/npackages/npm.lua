local constants = require("npackages.constants")
local job = require("npackages.utils.job")
local logger = require("npackages.logger")
local state = require("npackages.state")
local to_boolean = require("npackages.utils.to_boolean")
local util = require("npackages.util")

local M = {}
--- Checks if the currently opened file has content and JSON is in valid format
M.is_valid_package_json = function()
	local has_content = to_boolean(vim.api.nvim_buf_get_lines(0, 0, -1, false))

	if not has_content then
		return false
	end

	local buffer_content = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	if pcall(function()
		vim.json.decode(table.concat(buffer_content))
	end) then
		return true
	end

	return false
end

-- Check which lock file exists and set package manager accordingly
M.detect_package_manager = function()
	local yarn_lock = io.open("yarn.lock", "r")

	if yarn_lock ~= nil then
		job({
			command = "yarn -v",
			on_success = function(full_version)
				---@diagnostic disable-next-line: no-unknown
				local major_version = full_version:sub(1, 1)

				if major_version == "1" then
					state.has_old_yarn = true
				end
			end,
			on_error = function()
				logger.error("Error detecting yarn version. Falling back to yarn <2")
			end,
		})

		io.close(yarn_lock)

		return constants.PACKAGE_MANAGERS.yarn
	end

	local package_lock = io.open("package-lock.json", "r")

	if package_lock ~= nil then
		io.close(package_lock)

		return constants.PACKAGE_MANAGERS.npm
	end

	local pnpm_lock = io.open("pnpm-lock.yaml", "r")

	if pnpm_lock ~= nil then
		io.close(pnpm_lock)

		return constants.PACKAGE_MANAGERS.pnpm
	end
end

M.parse = function()
	if not M.is_valid_package_json() then
		return false
	end

	local buf = util.current_buf()
	state.package_manager[buf] = M.detect_package_manager()
	return true
end

return M
