local nio = require("nio")
local state = require("npackages.state")

describe("add with a floating input", function()
	local select, input, job, add, reload
	before_each(function()
		select, input = nio.ui.select, vim.ui.input
		job = package.loaded["npackages.lib.job"]
		add = package.loaded["npackages.command.add"]
		reload = package.loaded["npackages.ui.reload"]
	end)
	after_each(function()
		nio.ui.select, vim.ui.input = select, input
		package.loaded["npackages.lib.job"] = job
		package.loaded["npackages.command.add"] = add
		package.loaded["npackages.ui.reload"] = reload
	end)

	for _, kind in ipairs({ "Production", "Development" }) do
		it("preserves pnpm and cwd for " .. kind, function()
			local observed
			package.loaded["npackages.lib.job"] = function(props)
				observed = props
			end
			package.loaded["npackages.ui.reload"] = function() end
			package.loaded["npackages.command.add"] = nil
			local run = require("npackages.command.add")
			local dir = vim.fn.tempname()
			vim.cmd.enew()
			vim.api.nvim_buf_set_name(0, dir .. "/package.json")
			state.package_manager[vim.api.nvim_get_current_buf()] = "pnpm"
			nio.ui.select = function()
				return kind
			end
			vim.ui.input = function(_, callback)
				vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(false, true))
				callback("is-number")
			end
			run()
			assert.is_true(vim.wait(2000, function()
				return observed ~= nil
			end))
			assert.equals(dir, observed.cwd)
			local flag = kind == "Development" and "-D " or ""
			assert.equals("pnpm add " .. flag .. vim.fn.shellescape("is-number"), observed.command)
		end)
	end
end)
