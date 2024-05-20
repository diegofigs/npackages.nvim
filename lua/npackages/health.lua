local config = require("npackages.config.internal")
local util = require("npackages.util")

local M = {}

function M.check()
	vim.health.start("Configuration")
	if not config.validate_schema({}, config.schema, vim.g.npackages) then
		vim.health.ok("no issues found")
	else
		vim.health.error("does not pass schema validation")
	end

	vim.health.start("External Tools")
	if util.binary_installed("curl") then
		vim.health.ok("`curl` is installed")
	else
		vim.health.error("`curl` not found")
	end
	if util.binary_installed("npm") then
		vim.health.ok("`npm` is installed")
	else
		vim.health.error("`npm` not found")
	end

	local num = 0
	local cfg = config.build()
	for _, prg in ipairs(cfg.open_programs) do
		if util.binary_installed(prg) then
			vim.health.ok(string.format("`%s` is installed", prg))
			num = num + 1
		end
	end

	if num == 0 then
		local programs = table.concat(cfg.open_programs, " ")
		vim.health.warn("none of the following are installed " .. programs)
	end
end

return M
