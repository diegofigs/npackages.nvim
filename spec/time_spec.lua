local time = require("npackages.lib.time")
local DateTime = time.DateTime

describe("npackages.lib.time", function()
	it("can parse ISO 8601 timestamps", function()
		local input = "2018-03-01T21:13:57.964Z"

		local actual = DateTime.parse_iso_8601(input)
		local expected = DateTime.new(os.time({
			year = 2018,
			month = 3,
			day = 1,
			hour = 21,
			min = 13,
			sec = 57,
		}))

		assert.are_same(expected, actual)
	end)
end)
