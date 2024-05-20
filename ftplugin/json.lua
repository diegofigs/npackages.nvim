local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
if fname ~= "package.json" then
	return
end

if not vim.g.loaded_npackages then
	local ft = require("npackages.ft")
	ft.setup()

	vim.g.loaded_npackages = true
end
