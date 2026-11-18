-- Exercise real Snacks selection cleanup followed by the Add text prompt.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(assert(vim.env.NPACKAGES_NIO))
vim.opt.rtp:append(assert(vim.env.NPACKAGES_SNACKS))
require("snacks").setup({ input = { enabled = true }, picker = { enabled = true } })
vim.ui.select = Snacks.picker.select
vim.ui.input = Snacks.input.input
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/package.json")
require("npackages.state").package_manager[buf] = "pnpm"
require("npackages.command.add")()
local function fail(err)
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd("cquit 1")
end
vim.defer_fn(function()
	local ok, err = pcall(function()
		local picker = assert(Snacks.picker.get()[1], "selection picker did not open")
		picker:action("confirm")
	end)
	if not ok then
		return fail(err)
	end
	vim.defer_fn(function()
		local passed, message = pcall(function()
			assert(vim.bo.filetype == "snacks_input", "Add input did not open")
			assert(vim.fn.mode():match("^i"), "Add input is in " .. vim.fn.mode() .. " mode")
		end)
		if not passed then
			return fail(message)
		end
		print("PASS real Snacks Add prompt starts in insert mode")
		vim.cmd("qa!")
	end, 150)
end, 200)
