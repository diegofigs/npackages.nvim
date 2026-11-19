local server = require("npackages.lsp.server")

describe("embedded LSP transport", function()
	it("acknowledges replies, honors disabled capabilities, and exits once", function()
		local exits, replies = 0, {}
		local rpc = server.server()({
			on_exit = function()
				exits = exits + 1
			end,
		})
		local ok, id = rpc.request("initialize", {
			initializationOptions = { codeAction = false, hover = false, completion = false },
		}, function(err, result, response_id)
			assert.is_nil(err)
			assert.is_false(result.capabilities.codeActionProvider)
			assert.is_false(result.capabilities.hoverProvider)
			assert.is_nil(result.capabilities.completionProvider)
			assert.equals(1, response_id)
		end, function(response_id)
			table.insert(replies, response_id)
		end)
		assert.is_true(ok)
		assert.equals(1, id)
		rpc.request("unsupported/test", {}, function(err)
			assert.equals(-32601, err.code)
		end)
		rpc.request("shutdown", {}, function(err)
			assert.is_nil(err)
		end)
		assert.same({ 1 }, replies)
		assert.is_true(rpc.notify("exit", {}))
		rpc.terminate()
		assert.equals(1, exits)
		assert.is_true(rpc.is_closing())
	end)
end)
