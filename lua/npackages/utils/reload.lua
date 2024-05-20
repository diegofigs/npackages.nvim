--- Rereads the current buffer value and reloads the buffer
---@return nil
return function()
	vim.bo.autoread = true
	vim.cmd(":checktime")
end
