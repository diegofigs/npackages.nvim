local nio = require("nio")
local state = require("npackages.lsp.state")
local api = require("npackages.lib.api")
local workspace = require("npackages.lsp.workspace")
local diagnostic = require("npackages.lsp.textDocument.diagnostic")

local function diagnose(uri)
	local result
	diagnostic.diagnose({ textDocument = { uri = uri } }, function(err, response)
		assert.is_nil(err)
		result = response
	end)
	return result
end

describe("diagnostics during initial metadata loading", function()
	for _, succeeds in ipairs({ true, false }) do
		it(
			succeeds and "waits for metadata before diagnosing" or "reports a real failure after loading finishes",
			function()
				local uri = "file:///npackages-loading/package.json"
				local original, cache = api.curl_package, state.api_cache
				state.api_cache = {}
				state.documents[uri] = {
					uri = uri,
					text = '{\n  "dependencies": {\n    "pure-rand": "6.1.0"\n  }\n}',
				}
				local gate = nio.control.event()
				local started, finished, task_error = false, false, nil
				api.curl_package = function()
					started = true
					gate.wait()
					if not succeeds then
						error("registry unavailable")
					end
					return table.concat(vim.fn.readfile("spec/mocks/api/pure-rand.json"), "\n")
				end
				nio.run(function()
					workspace.refresh(uri)
				end, function(ok, err)
					finished, task_error = true, not ok and err or nil
				end)
				local did_start = vim.wait(1000, function()
					return started
				end)
				local pending_ok, pending = pcall(diagnose, uri)
				gate.set()
				local did_finish = vim.wait(3000, function()
					return finished
				end)
				local loaded_ok, loaded = pcall(diagnose, uri)
				api.curl_package, state.api_cache = original, cache
				state.documents[uri], state.doc_cache[uri], state.diagnostics[uri] = nil, nil, nil
				assert.is_true(did_start)
				assert.is_true(pending_ok, tostring(pending))
				assert.same({}, pending.items)
				assert.is_true(did_finish)
				assert.is_nil(task_error)
				assert.is_true(loaded_ok, tostring(loaded))
				local fetch_error = false
				for _, item in ipairs(loaded.items) do
					if item.code == "package_error_fetching" then
						fetch_error = true
					end
				end
				assert.equals(not succeeds, fetch_error)
			end
		)
	end

	it("preserves published diagnostics while a later refresh is loading", function()
		local uri = "file:///npackages-refreshing/package.json"
		local previous = { { code = "vers_upgrade", message = "Upgrade available" } }
		state.documents[uri] = { uri = uri }
		state.doc_cache[uri] = { loading = true }
		state.diagnostics[uri] = previous
		local ok, result = pcall(diagnose, uri)
		local published = state.diagnostics[uri]
		state.documents[uri], state.doc_cache[uri], state.diagnostics[uri] = nil, nil, nil
		assert.is_true(ok, tostring(result))
		assert.same(previous, result.items)
		assert.equals(previous, published)
	end)

	it("returns no premature errors before the document cache exists", function()
		local uri = "file:///npackages-before-cache/package.json"
		state.documents[uri] = { uri = uri }
		local ok, result = pcall(diagnose, uri)
		state.documents[uri] = nil
		assert.is_true(ok, tostring(result))
		assert.same({}, result.items)
	end)
end)
