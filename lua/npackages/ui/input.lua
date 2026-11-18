local nio = require("nio")

-- vim.ui.input providers may open a prompt while another picker is still
-- restoring normal mode. A timer turn lets queued picker cleanup and mode
-- changes finish; vim.schedule alone can still run before that cleanup.
return nio.wrap(function(opts, callback)
	local pending = true
	vim.ui.input(opts, function(value)
		pending = false
		callback(value)
	end)
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(win)
	local is_prompt = vim.bo[buf].buftype == "prompt"
		or vim.bo[buf].filetype == "snacks_input"
		or vim.bo[buf].filetype == "DressingInput"
	if not pending or not is_prompt then
		return
	end
	vim.defer_fn(function()
		if
			pending
			and vim.api.nvim_win_is_valid(win)
			and vim.api.nvim_get_current_win() == win
			and vim.api.nvim_win_get_buf(win) == buf
		then
			vim.cmd("startinsert!")
		end
	end, 0)
end, 2)
