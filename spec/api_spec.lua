local nio = require("nio")
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
				},
			},
		}, metadata)
	end)

	-- nio.tests.it("can fetch package metadata", function()
	-- 	local metadata = api.curl_package("pure-rand")
	-- 	assert.not_nil(metadata)
	-- end)
	--
	-- nio.tests.it("can fetch package metadata in bulk", function()
	-- 	local metadatas = api.fetch_packages({ "pure-rand", "uuid" })
	-- 	for _, meta in pairs(metadatas) do
	-- 		assert.not_nil(meta)
	-- 	end
	-- end)
end)
