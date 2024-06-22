local job = require("npackages.lib.job")
local logger = require("npackages.logger")
local state = require("npackages.state")
local util = require("npackages.util")

local M = {}

M.PACKAGE_MANAGERS = {
	yarn = "yarn",
	npm = "npm",
	pnpm = "pnpm",
}

--- Checks if the currently opened file has content and JSON is in valid format
M.is_valid_package_json = function()
	local value = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	local has_content = true
	if value == nil then
		return false
	end

	if type(value) == "table" and vim.tbl_isempty(value) then
		return false
	end

	if type(value) == "string" and value == "" then
		return false
	end

	if not has_content then
		return false
	end

	local buffer_content = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	local valid = pcall(function()
		vim.json.decode(table.concat(buffer_content))
	end)

	return valid
end

-- Check which lock file exists and set package manager accordingly
M.detect_package_manager = function()
	-- Get the current cwd and use it as the value for
	-- cwd in case no package.json is open right now
	local cwd = vim.fn.getcwd()

	-- Get the path of the opened file if there is one
	local file_path = vim.fn.expand("%:p")

	-- If the file is a package.json then use the directory
	-- of the file as value for cwd
	if string.sub(file_path, -12) == "package.json" then
		cwd = string.sub(file_path, 1, -13)
	end

	local yarn_lock = io.open(cwd .. "/yarn.lock", "r")

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

		return M.PACKAGE_MANAGERS.yarn
	end

	local package_lock = io.open(cwd .. "package-lock.json", "r")

	if package_lock ~= nil then
		io.close(package_lock)

		return M.PACKAGE_MANAGERS.npm
	end

	local pnpm_lock = io.open(cwd .. "/pnpm-lock.yaml", "r")

	if pnpm_lock ~= nil then
		io.close(pnpm_lock)

		return M.PACKAGE_MANAGERS.pnpm
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
