local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
if fname ~= "package.json" then
	return
end

if not vim.g.loaded_npackages then
	vim.g.loaded_npackages = true

	local ft = require("npackages.ft")
	ft.setup()
end

local state = require("npackages.state")
if state.cfg.lsp.enabled then
	require("npackages.lsp").start()
end
