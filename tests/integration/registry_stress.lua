-- Opt-in real LSP/first-open reproduction for large registry responses.
vim.opt.rtp:prepend(vim.fn.getcwd())
vim.opt.rtp:append(assert(vim.env.NPACKAGES_NIO))
local state = require("npackages.lsp.state")
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
local filename = directory .. "/package.json"
vim.fn.writefile(vim.fn.readfile("tests/integration/fixtures/registry-stress.json"), filename)
local ticks, maximum_gap = 0, 0
local start, previous = vim.uv.hrtime(), vim.uv.hrtime()
local timer = vim.uv.new_timer()
timer:start(10, 10, function()
	local now = vim.uv.hrtime()
	maximum_gap = math.max(maximum_gap, (now - previous) / 1e6)
	previous, ticks = now, ticks + 1
end)
vim.cmd("filetype plugin on")
vim.cmd.edit(filename)
local buf = vim.api.nvim_get_current_buf()
local uri = vim.uri_from_bufnr(buf)
local completed = vim.wait(120000, function()
	local cache = state.doc_cache[uri]
	return cache and not cache.loading and vim.tbl_count(cache.info) == 18
end)
timer:stop()
timer:close()
local ok, err = pcall(function()
	assert(completed, "first-open LSP indexing/diagnostics did not resolve all 18 packages")
	local cache, count = state.doc_cache[uri], 0
	for key, package in pairs(cache.packages) do
		if package.dep_kind == 1 then
			assert(state.api_cache[package:package()], "missing metadata: " .. package:package())
			assert(cache.info[key].vers_match, "no first-load matching version: " .. package:package())
			count = count + 1
		end
	end
	for _, item in ipairs(state.diagnostics[uri]) do
		assert(item.code ~= "package_error_fetching", item.message)
	end
	local namespace = vim.api.nvim_get_namespaces()["npackages.nvim"]
	assert(
		vim.wait(3000, function()
			return namespace and #vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, {}) == 18
		end),
		"missing first-load version annotations"
	)
	assert(count == 18)
	assert(not state.api_cache["@example/common"] and not state.api_cache["@example/db"])
	assert(ticks > 0, "no event-loop ticks during indexing")
	print(
		string.format(
			"PASS: %d first-load versions/annotations, %.2fs, %d timer ticks, largest gap %.1fms",
			count,
			(vim.uv.hrtime() - start) / 1e9,
			ticks,
			maximum_gap
		)
	)
end)
for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
	client:stop(true)
end
vim.fn.delete(directory, "rf")
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd("cquit 1")
end
vim.cmd("qa!")
