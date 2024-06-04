local api = require("npackages.api")
local time = require("npackages.time")
local DateTime = time.DateTime
local types = require("npackages.types")
local SemVer = types.SemVer

describe("npackages.json", function()
	it("can parse json", function()
		---@type string
		local json_str = io.open("spec/mocks/pure-rand.json"):read("a")
		local crate = api.parse_crate(json_str)
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
		}, crate)
	end)

	it("can parse empty dependencies", function()
		local json_str = io.open("spec/mocks/pure-rand_dependencies.json"):read("a")
		local dependencies = api.parse_deps(json_str)
		assert.equals("table", type(dependencies))

		-- 	assert.same({
		-- 		{
		-- 			name = "average",
		-- 			opt = false,
		-- 			kind = ApiDependencyKind.DEV,
		-- 			vers = {
		-- 				reqs = {
		-- 					{
		-- 						cond = Cond.CR,
		-- 						cond_col = Span.new(0, 1),
		-- 						vers = SemVer.new({ major = 0, minor = 9, patch = 2 }),
		-- 						vers_col = Span.new(1, 6),
		-- 					},
		-- 				},
		-- 				text = "^0.9.2",
		-- 			},
		-- 		},
		-- 		{
		-- 			name = "rand_core",
		-- 			opt = false,
		-- 			kind = ApiDependencyKind.NORMAL,
		-- 			vers = {
		-- 				reqs = {
		-- 					{
		-- 						cond = Cond.CR,
		-- 						cond_col = Span.new(0, 1),
		-- 						vers = SemVer.new({ major = 0, minor = 3 }),
		-- 						vers_col = Span.new(1, 4),
		-- 					},
		-- 				},
		-- 				text = "^0.3",
		-- 			},
		-- 		},
		-- 		{
		-- 			name = "rustc_version",
		-- 			opt = false,
		-- 			kind = ApiDependencyKind.BUILD,
		-- 			vers = {
		-- 				reqs = {
		-- 					{
		-- 						cond = Cond.CR,
		-- 						cond_col = Span.new(0, 1),
		-- 						vers = SemVer.new({ major = 0, minor = 2 }),
		-- 						vers_col = Span.new(1, 4),
		-- 					},
		-- 				},
		-- 				text = "^0.2",
		-- 			},
		-- 		},
		-- 		{
		-- 			name = "cloudabi",
		-- 			opt = true,
		-- 			kind = ApiDependencyKind.NORMAL,
		-- 			vers = {
		-- 				reqs = {
		-- 					{
		-- 						cond = Cond.CR,
		-- 						cond_col = Span.new(0, 1),
		-- 						vers = SemVer.new({ major = 0, minor = 0, patch = 3 }),
		-- 						vers_col = Span.new(1, 6),
		-- 					},
		-- 				},
		-- 				text = "^0.0.3",
		-- 			},
		-- 		},
		-- 	}, dependencies)
	end)
end)
