local logger = require("npackages.logger")
local nio = require("nio")

---@class JobProps
---@field command string - string command to run
---@field on_success? function - function to invoke with the results
---@field on_error? function - function to invoke if the command fails
---@field on_start? function - callback to invoke before the job starts
---@field ignore_error? boolean - ignore non-zero exit codes (npm outdated throws 1 when getting the list)
---@field output? boolean log output

--- Runs an async job
---@param props JobProps
return function(props)
	local ignore_errors = props.ignore_error or false
	local log_output = props.output or false

	local function on_error()
		logger.error("Error running " .. props.command .. ". Try running manually.")

		pcall(props.on_error)
	end

	local function on_exit(exit_code, message)
		if exit_code == 0 then
			logger.info(message)
		else
			logger.error(message)
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

	local out = ""
	local err = ""
	local out_count = 0
	local err_count = 0

	pcall(props.on_start)
	nio.fn.jobstart(props.command, {
		cwd = cwd,
		on_exit = function(_, exit_code)
			if log_output then
				on_exit(exit_code, string.format("(%s) exited with (%s):\n%s\n%s", props.command, exit_code, out, err))
			end

			if exit_code ~= 0 and not ignore_errors then
				on_error()
				return
			end

			props.on_success(out)
		end,
		on_stdout = function(_, stdout)
			out_count = out_count + 1
			out = out .. "\n" .. table.concat(stdout)
		end,
		on_stderr = function(_, stderr)
			err_count = err_count + 1
			err = err .. "\n" .. table.concat(stderr)
		end,
	})
end
