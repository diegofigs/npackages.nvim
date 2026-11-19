--- Reread the original buffer after a package manager changes it on disk.
--- Safe from both regular job callbacks and nio tasks.
return function(buf)
	vim.schedule(function()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		vim.bo[buf].autoread = true
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("checktime")
		end)
	end)
end
