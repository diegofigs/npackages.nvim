-- Run with: nvim --headless -u NONE -c "lua dofile('tests/integration/input_mode.lua')"
-- NPACKAGES_NIO must point to an nvim-nio checkout.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(assert(vim.env.NPACKAGES_NIO))
local prompt, finished = nil, false
vim.ui.input = function(_, callback)
	prompt = vim.api.nvim_create_buf(false, true)
	vim.bo[prompt].buftype = "prompt"
	vim.api.nvim_open_win(prompt, true, { relative = "editor", row = 1, col = 1, width = 40, height = 1 })
	vim.cmd("stopinsert") -- model a provider/picker leaving the prompt in normal mode
	vim.defer_fn(function()
		local ok, err = pcall(function()
			assert(vim.fn.mode():match("^i"), "prompt did not enter insert mode: " .. vim.fn.mode())
			callback("is-number")
			assert(finished, "input result was not delivered")
		end)
		if not ok then
			io.stderr:write(tostring(err) .. "\n")
			vim.cmd("cquit 1")
		end
		print("PASS input opens in insert mode and delivers result")
		vim.cmd("qa!")
	end, 100)
end
require("nio").run(function()
	local value = require("npackages.ui.input")({ prompt = "Package" })
	assert(value == "is-number")
	finished = true
end)
