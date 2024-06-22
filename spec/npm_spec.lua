local npm = require("npackages.lib.npm")

describe("npackages.lib.npm", function()
	it("can validate json file", function()
		vim.cmd.edit("spec/mocks/api/pure-rand.json")
		local valid_result = npm.is_valid_package_json()
		assert.is_true(valid_result)

		vim.cmd.edit("spec/mocks/api/invalid.json")
		local invalid_result = npm.is_valid_package_json()
		assert.is_false(invalid_result)
	end)

	it("can detect package manager", function()
		vim.cmd.edit("spec/mocks/npm/package.json")
		local npm_result = npm.detect_package_manager()
		assert.equals("npm", npm_result)

		vim.cmd.edit("spec/mocks/yarn/package.json")
		local yarn_result = npm.detect_package_manager()
		assert.equals("yarn", yarn_result)

		vim.cmd.edit("spec/mocks/pnpm/package.json")
		local pnpm_result = npm.detect_package_manager()
		assert.equals("pnpm", pnpm_result)
	end)
end)
