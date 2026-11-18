-- local nio = require("nio")
local api = require("npackages.lib.api")
local time = require("npackages.lib.time")
local semver = require("npackages.lib.semver")
local DateTime = time.DateTime
local SemVer = semver.SemVer

describe("npackages.lib.api", function()
	it("can parse json", function()
		local json_str = io.open("spec/mocks/api/pure-rand.json"):read("a")
		local decoded = vim.json.decode(json_str)
		local metadata = api.parse_metadata(decoded)
		--- TODO: test dependencies parsing
		metadata.versions[1].dependencies = {}
		metadata.versions[1].devDependencies = {}
		assert.has_same({
			name = "pure-rand",
			description = " Pure random number generator written in TypeScript",
			created = DateTime.new(os.time({
				year = 2018,
				month = 3,
				day = 1,
				hour = 21,
				min = 13,
				sec = 57,
			})),
			updated = DateTime.new(os.time({
				year = 2024,
				month = 3,
				day = 20,
				hour = 21,
				min = 29,
				sec = 49,
			})),
			-- downloads = 168678835,
			homepage = "https://github.com/dubzzz/pure-rand#readme",
			-- documentation = "https://docs.rs/rand",
			repository = "https://github.com/dubzzz/pure-rand",
			categories = {},
			keywords = {
				"seed",
				"random",
				"prng",
				"generator",
				"pure",
				"rand",
				"mersenne",
				"random number generator",
				"fastest",
				"fast",
			},
			versions = {
				{
					num = "6.1.0",
					parsed = SemVer.new({ major = 6, minor = 1, patch = 0 }),
					created = DateTime.new(os.time({
						year = 2024,
						month = 3,
						day = 20,
						hour = 21,
						min = 29,
						sec = 49,
					})),
					dependencies = {},
					devDependencies = {},
				},
			},
		}, metadata)
	end)

	-- nio.tests.it("can fetch package metadata", function()
	-- 	local metadata = api.curl_package("pure-rand")
	-- 	assert.not_nil(metadata)
	-- end)
end)

describe("registry fetch transport", function()
	for _, exit_code in ipairs({ 0, 28 }) do
		it(
			exit_code == 0 and "reads a completed temporary download" or "rejects partial timed-out downloads",
			function()
				local nio = require("nio")
				local original, observed, output_path = vim.system, nil, nil
				local original_close, close_count = nio.uv.fs_close, 0
				nio.uv.fs_close = function(...)
					close_count = close_count + 1
					return original_close(...)
				end
				vim.system = function(args, _, callback)
					observed = args
					for index, argument in ipairs(args) do
						if argument == "--output" then
							output_path = args[index + 1]
						end
					end
					assert.is_not_nil(output_path, "large registry payloads must download to a file")
					vim.fn.writefile({ "metadata" }, output_path, "b")
					vim.schedule(function()
						callback({ code = exit_code })
					end)
				end
				local done, ok, result = false, false, nil
				nio.run(function()
					result = api.curl_package("pure-rand")
				end, function(success, err)
					done, ok = true, success
					if not success then
						result = err
					end
				end)
				local finished = vim.wait(1000, function()
					return done
				end)
				vim.system = original
				nio.uv.fs_close = original_close
				assert.equals(exit_code == 0 and 1 or 0, close_count, "read descriptor must close exactly once")
				assert.is_true(finished)
				assert.equals(exit_code == 0, ok, tostring(result))
				assert.equals(0, vim.fn.filereadable(output_path))
				if ok then
					assert.equals("metadata", result)
				end
				assert.equals("curl", observed[1])
				assert.equals("-sL", observed[2])
				assert.equals("npackages.nvim (https://github.com/diegofigs/npackages.nvim)", observed[6])
				assert.is_true(vim.tbl_contains(observed, "--compressed"))
			end
		)
	end

	it("cleans up a download after its indexing task is cancelled", function()
		local nio = require("nio")
		local original, output_path, complete = vim.system, nil, nil
		vim.system = function(args, _, callback)
			for index, argument in ipairs(args) do
				if argument == "--output" then
					output_path = args[index + 1]
				end
			end
			vim.fn.writefile({ "metadata" }, output_path, "b")
			complete = callback
		end
		local task = nio.run(function()
			api.curl_package("pure-rand")
		end, function() end)
		local started = vim.wait(1000, function()
			return complete ~= nil
		end)
		task.cancel()
		if complete then
			complete({ code = 0 })
		end
		local cleaned = vim.wait(1000, function()
			return output_path and vim.fn.filereadable(output_path) == 0
		end)
		vim.system = original
		assert.is_true(started and cleaned)
	end)
end)
