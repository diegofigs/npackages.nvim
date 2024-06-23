local job = require("npackages.lib.job")

describe("npackages.lib.job", function()
	before_each(function()
		vim.cmd.edit("spec/mocks/npm/package.json")
	end)

	it("can return output for valid command", function()
		local actual = ""
		job({
			command = "ls",
			on_success = function(result)
				actual = result
			end,
		})

		vim.wait(10000, function()
			return actual ~= ""
		end)
	end)

	it("can return error for invalid command", function()
		local actual = ""
		job({
			command = "invalid_cmd",
			on_error = function(result)
				actual = result
			end,
		})

		vim.wait(10000, function()
			return actual ~= ""
		end)
	end)
end)
