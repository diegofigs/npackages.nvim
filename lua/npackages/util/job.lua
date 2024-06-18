local logger = require("npackages.logger")
local json = require("npackages.util.json")

---@class JobProps
---@field command string - string command to run
---@field on_success? function - function to invoke with the results
---@field on_error? function - function to invoke if the command fails
---@field on_start? function - callback to invoke before the job starts
---@field ignore_error? boolean - ignore non-zero exit codes (npm outdated throws 1 when getting the list)
---@field json? boolean - parse as json

--- Runs an async job
---@param props JobProps
return function(props)
	local value = ""

	pcall(props.on_start)

	local function on_error()
		logger.error("Error running " .. props.command .. ". Try running manually.")

		if props.on_error ~= nil then
			props.on_error()
		end
	end

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

	vim.fn.jobstart(props.command, {
		cwd = cwd,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 and not props.ignore_error then
				on_error()

				return
			end

			if props.json then
				local ok, json_value = pcall(json.decode, value)

				if ok then
					props.on_success(json_value)

					return
				end

				on_error()
			else
				props.on_success(value)
			end
		end,
		on_stdout = function(_, stdout)
			value = value .. table.concat(stdout)
		end,
	})
end
