local lsp = require("npackages.lsp")
local server = require("npackages.lsp.server")

describe("npackages.lsp", function()
	before_each(function()
		local state = require("npackages.state")
		local cfg = require("npackages.config.internal").build()
		state.cfg = cfg

		-- Reset the server messages before each test
		server.messages = {}
	end)

	it("can receive textDocument notifications", function()
		vim.cmd.edit("spec/mocks/lsp/package.json")
		lsp.start()

		-- Wait for the textDocument/didOpen notification
		assert(
			vim.wait(3000, function()
				for _, msg in ipairs(server.messages) do
					if msg.method == "textDocument/didOpen" then
						return true
					end
				end
				return false
			end),
			"Failed to receive textDocument/didOpen notification"
		)

		-- Simulate editing the file to generate a textDocument/didChange notification
		local bufnr = vim.api.nvim_get_current_buf()
		local line_count = vim.api.nvim_buf_line_count(bufnr)
		vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, { "Adding a new line" })

		-- Wait for the textDocument/didChange notification
		assert(
			vim.wait(3000, function()
				for _, msg in ipairs(server.messages) do
					if msg.method == "textDocument/didChange" then
						return true
					end
				end
				return false
			end),
			"Failed to receive textDocument/didChange notification"
		)

		-- Close the buffer to trigger textDocument/didClose notification
		vim.cmd("bwipeout! " .. bufnr)

		-- Wait for the textDocument/didClose notification
		assert(
			vim.wait(3000, function()
				for _, msg in ipairs(server.messages) do
					if msg.method == "textDocument/didClose" then
						return true
					end
				end
				return false
			end),
			"Failed to receive textDocument/didClose notification"
		)
	end)
end)
