local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
if fname == "package.json" then
	require("npackages.ft").activate()
end
