local Logger = {}

--- Prints a message with a given highlight group
---@param message any message to print
---@param highlight_group string | nil highlight group to use when printing the message
---@return nil
local function __print(message, level, highlight_group)
	vim.notify(
		"Npackages: " .. vim.inspect(message),
		level or vim.log.levels.TRACE,
		{ title = "npackages.nvim", highlight_group = highlight_group }
	)
end

--- Prints an error message
--- For notifying the user about a critical failure
Logger.error = function(message)
	__print(message, vim.log.levels.ERROR, "ErrorMsg")
end

--- Prints a warning message
--- For notifying the user about a non critical failure
Logger.warn = function(message)
	__print(message, vim.log.levels.WARN("WarningMsg"))
end

--- Prints an info message
--- For notifying the user about something not important
Logger.info = function(message)
	__print(message, vim.log.levels.INFO)
end

return Logger
