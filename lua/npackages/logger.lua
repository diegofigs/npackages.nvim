local M = {}

--- Prints a message with a given highlight group
---@param message string | nil message to print
---@param highlight_group string | nil highlight group to use when printing the message
---@return nil
local function __print(message, highlight_group)
	vim.api.nvim_echo({ { "Npackages: " .. message, highlight_group or "" } }, true, {})
end

--- Prints an error message
--- For notifying the user about a critical failure
---@param message string | nil error message to print
---@return nil
M.error = function(message)
	__print(message, "ErrorMsg")
end

--- Prints a warning message
--- For notifying the user about a non critical failure
---@param message string | nil warning message to print
---@return nil
M.warn = function(message)
	__print(message, "WarningMsg")
end

--- Prints an info message
--- For notifying the user about something not important
---@param message string | nil - info message to print
---@return nil
M.info = function(message)
	__print(message)
end

return M
