local state = require("npackages.lsp.state")
local actions = require("npackages.lsp.textDocument.codeAction")

describe("code actions without fetched metadata", function()
	it("keeps the registry action without indexing missing diagnostics or URLs", function()
		local uri = "file:///npackages-missing-metadata/package.json"
		state.documents[uri] = { uri = uri }
		state.doc_cache[uri] = {
			packages = {
				dependency = {
					range = { start = { line = 2 }, ["end"] = { line = 2 } },
					package = function()
						return "npackages-missing-metadata"
					end,
				},
			},
			info = {},
		}
		local ok, result = pcall(actions.get, {
			textDocument = { uri = uri },
			range = { start = { line = 2 }, ["end"] = { line = 2 } },
			context = { diagnostics = {} },
		})
		state.documents[uri], state.doc_cache[uri] = nil, nil
		assert.is_true(ok, tostring(result))
		assert.equals(1, #result)
		assert.equals("Open npmjs.org", result[1].title)
	end)
end)
