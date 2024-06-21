local api = require("npackages.lsp.system")
local time = require("npackages.lib.time")
local json = require("npackages.lib.json")
local DateTime = time.DateTime
local semver = require("npackages.lib.semver")
local SemVer = semver.SemVer

describe("npackages.lsp.system", function()
	it("can parse json", function()
		local json_str = io.open("spec/mocks/pure-rand.json"):read("a")
		local decoded = json.decode(json_str)
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
end)
