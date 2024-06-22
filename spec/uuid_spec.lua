local uuid = require("npackages.lib.uuid")

describe("npackages.lib.uuid", function()
	it("can generate 100 unique values", function()
		local values = {}
		for _ = 1, 100 do
			table.insert(values, uuid())
		end
		assert.are_unique(values)
	end)
end)
