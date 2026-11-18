local nio = require("nio")
local api = require("npackages.lib.api")
local scanner = require("npackages.lsp.scanner")
local workspace = require("npackages.lsp.workspace")
local state = require("npackages.lsp.state")

local function await(fn)
	local done, failure = false, nil
	nio.run(fn, function(ok, err)
		done, failure = true, not ok and err or nil
	end)
	assert.is_true(vim.wait(5000, function()
		return done
	end))
	assert.is_nil(failure)
end

describe("registry fetch responsiveness", function()
	it("yields during large metadata conversion so timers can run", function()
		local raw = {
			name = "large",
			description = "fixture",
			time = {
				created = "2024-01-01T00:00:00.000Z",
				modified = "2024-01-01T00:00:00.000Z",
			},
			versions = {},
		}
		for i = 1, 1000 do
			local version = "1.0." .. i
			raw.time[version] = raw.time.created
			raw.versions[version] = { version = version }
		end
		local yielded, timer_ran, responsive = 0, false, false
		await(function()
			vim.defer_fn(function()
				timer_ran = true
			end, 1)
			local metadata = api.parse_metadata(raw, function()
				yielded = yielded + 1
				nio.sleep(1)
				responsive = responsive or timer_ran
			end)
			assert.equals(1000, #metadata.versions)
		end)
		assert.is_true(yielded > 0 and responsive)
	end)

	it("recognizes workspace and local specs without parsing registry ranges", function()
		for spec, kind in pairs({
			["workspace:*"] = scanner.DepKind.WORKSPACE,
			["workspace:^"] = scanner.DepKind.WORKSPACE,
			["file:../local"] = scanner.DepKind.PATH,
			["link:../local"] = scanner.DepKind.PATH,
		}) do
			local _, packages =
				scanner.scan_package_doc({ "{", '"dependencies": {', '"local-pkg": "' .. spec .. '"', "}", "}" })
			assert.equals(1, #packages)
			assert.equals(kind, packages[1].dep_kind)
			assert.same({}, packages[1]:vers_reqs())
		end
	end)

	it("bounds parallel requests and never fetches explicit workspace dependencies", function()
		local uri = "file:///npackages-fetch-limit/package.json"
		local lines = { "{", '"dependencies": {', '"internal": "workspace:*",' }
		for i = 1, 8 do
			table.insert(lines, '"external-' .. i .. '": "1.0.0",')
		end
		table.insert(lines, "}")
		table.insert(lines, "}")
		state.documents[uri] = { uri = uri, text = table.concat(lines, "\n") }
		local original, old_cache = api.curl_package, state.api_cache
		state.api_cache = {}
		local active, maximum, requests, internal = 0, 0, 0, false
		api.curl_package = function(name)
			requests, active = requests + 1, active + 1
			internal = internal or name == "internal"
			maximum = math.max(maximum, active)
			nio.sleep(10)
			active = active - 1
			return "{}" -- failed registry responses still release a slot
		end
		local ok, err = pcall(await, function()
			workspace.refresh(uri)
		end)
		api.curl_package, state.api_cache = original, old_cache
		state.documents[uri], state.doc_cache[uri] = nil, nil
		assert.is_true(ok, tostring(err))
		assert.equals(8, requests)
		assert.is_false(internal)
		assert.is_true(maximum <= 4)
	end)
end)
