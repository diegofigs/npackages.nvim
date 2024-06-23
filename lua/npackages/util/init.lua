local state = require("npackages.state")
local lsp_state = require("npackages.lsp.state")
local logger = require("npackages.logger")

local M = {}

local IS_WIN = vim.api.nvim_call_function("has", { "win32" }) == 1

---@return integer
function M.current_buf()
	return vim.api.nvim_get_current_buf()
end

---@return integer, integer
function M.cursor_pos()
	local cursor = vim.api.nvim_win_get_cursor(0)
	return cursor[1] - 1, cursor[2]
end

---@param uri lsp.DocumentUri
---@param pos lsp.Position
---@return JsonPackage|nil
function M.get_package_in_position(uri, pos)
	local cache = lsp_state.doc_cache[uri]
	local packages = cache and cache.packages
	if not packages then
		return {}
	end

	local pkg = nil
	for _, p in pairs(packages) do
		if pos.line == p.lines.s then
			pkg = p
		end
	end

	return pkg
end

---@param uri lsp.DocumentUri
---@param range lsp.Range
---@return table<string,JsonPackage>
function M.get_packages_in_range(uri, range)
	local cache = lsp_state.doc_cache[uri]
	local packages = cache and cache.packages
	if not packages then
		return {}
	end

	local range_s = range.start.line
	local range_e = range["end"].line

	---@type table<string,JsonPackage>
	local packages_in_range = {}
	for k, p in pairs(packages) do
		local pkg_start = p.lines.s
		-- INFO: counteracts Span +1 indexing
		local pkg_end = p.lines.e - 1
		if range_s <= pkg_start and pkg_end <= range_e then
			packages_in_range[k] = p
		end
	end

	return packages_in_range
end

---comment
---@param name string
---@return boolean
function M.binary_installed(name)
	if IS_WIN then
		name = name .. ".exe"
	end

	return vim.fn.executable(name) == 1
end

---@param name string
---@return string
function M.package_url(name)
	return "https://www.npmjs.com/package/" .. name
end

---@param url string
function M.open_url(url)
	for _, prg in ipairs(state.cfg.open_programs) do
		if M.binary_installed(prg) then
			vim.cmd(string.format("silent !%s %s", prg, url))
			return
		end
	end

	logger.warn("Couldn't open url")
end

return M
