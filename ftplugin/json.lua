local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
if fname ~= "package.json" then
	return
end

if vim.g.loaded_npackages then
	return
end
vim.g.loaded_npackages = true

local ft = require("npackages.ft")
ft.setup()
