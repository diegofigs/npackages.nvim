local nio = require("nio")
local state = require("npackages.lsp.state")
local plugin = require("npackages.state")
local api = require("npackages.lib.api")
local client = require("npackages.lsp.client")
local server = require("npackages.lsp.server")
local diagnostic = require("npackages.lsp.textDocument.diagnostic")
local extmark = require("npackages.ui.extmark")

local lines = { "{", '"dependencies": {', '"pure-rand": "6.1.0"', "}", "}" }

describe("document indexing lifecycle", function()
	local original_fetch, original_request, original_session, original_cache, original_cfg, original_visible
	local rpc, buffers, uris, gate, requests
	before_each(function()
		original_fetch, original_request = api.curl_package, client.request_diagnostics
		original_session, original_cache = state.session, state.api_cache
		original_cfg, original_visible = plugin.cfg, plugin.visible
		state.session, state.api_cache = { task_queue = {} }, {}
		plugin.cfg, plugin.visible = require("npackages.config.internal").build(), true
		buffers, uris, requests = {}, {}, {}
		gate = nio.control.event()
		api.curl_package = function()
			gate.wait()
			return table.concat(vim.fn.readfile("spec/mocks/api/pure-rand.json"), "\n")
		end
		client.request_diagnostics = function(uri)
			diagnostic.diagnose({ textDocument = { uri = uri } }, function(err)
				assert.is_nil(err)
			end)
			requests[uri] = (requests[uri] or 0) + 1
		end
		rpc = server.server()({ notification = function() end, on_exit = function() end })
	end)
	after_each(function()
		gate.set()
		for _, task in pairs(state.session.task_queue) do
			task.cancel()
		end
		api.curl_package, client.request_diagnostics = original_fetch, original_request
		for _, uri in ipairs(uris) do
			state.documents[uri], state.doc_cache[uri], state.diagnostics[uri] = nil, nil, nil
		end
		for _, buf in ipairs(buffers) do
			extmark.clear(buf)
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		state.session, state.api_cache = original_session, original_cache
		plugin.cfg, plugin.visible = original_cfg, original_visible
	end)

	local function open()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/package.json")
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		local uri = vim.uri_from_bufnr(buf)
		table.insert(buffers, buf)
		table.insert(uris, uri)
		rpc.notify("textDocument/didOpen", { textDocument = { uri = uri, text = table.concat(lines, "\n") } })
		return uri, buf
	end

	it("finishes diagnostics and annotations for both buffers opened during fetching", function()
		local first, a = open()
		local second, b = open()
		gate.set()
		assert.is_true(vim.wait(2000, function()
			return requests[first] and requests[second]
		end))
		assert.is_false(state.doc_cache[first].loading)
		assert.is_false(state.doc_cache[second].loading)
		local namespace = vim.api.nvim_get_namespaces()["npackages.nvim"]
		assert.equals(1, #vim.api.nvim_buf_get_extmarks(a, namespace, 0, -1, {}))
		assert.equals(1, #vim.api.nvim_buf_get_extmarks(b, namespace, 0, -1, {}))
		extmark.clear(a)
		assert.equals(1, #vim.api.nvim_buf_get_extmarks(b, namespace, 0, -1, {}))
	end)

	it("publishes only the newest edit for the same document", function()
		local uri = open()
		local older = state.doc_cache[uri]
		local updated = table.concat(lines, "\n"):gsub("6.1.0", "^6.1.0")
		rpc.notify("textDocument/didChange", {
			textDocument = { uri = uri },
			contentChanges = { { text = updated } },
		})
		local latest = state.doc_cache[uri]
		gate.set()
		assert.is_true(vim.wait(2000, function()
			return requests[uri] ~= nil
		end))
		assert.equals(1, requests[uri])
		assert.is_false(latest.loading)
		assert.equals(latest, state.doc_cache[uri])
		assert.is_not.equals(older, latest)
		assert.equals(updated, state.documents[uri].text)
	end)

	it("does not publish or render work for a closed buffer", function()
		local uri = open()
		rpc.notify("textDocument/didClose", { textDocument = { uri = uri } })
		gate.set()
		vim.wait(50)
		assert.is_nil(requests[uri])
		assert.is_nil(state.doc_cache[uri])
	end)
end)
