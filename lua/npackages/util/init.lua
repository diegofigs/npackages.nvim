local state = require("npackages.state")
local lsp_state = require("npackages.lsp.state")
local types = require("npackages.types")
local Span = types.Span
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

---@return Span
function M.selected_lines()
	local info = vim.api.nvim_get_mode()
	if info.mode:match("[vV]") then
		local s = vim.fn.getpos("v")[2]
		local e = vim.fn.getcurpos()[2]
		return Span.new(s, e)
	else
		local s = vim.api.nvim_buf_get_mark(0, "<")[1]
		local e = vim.api.nvim_buf_get_mark(0, ">")[1]
		return Span.new(s, e)
	end
end

---@param uri lsp.DocumentUri
function M.get_lsp_info(uri)
	local cache = lsp_state.doc_cache[uri]
	return cache and cache.info
end

---@param uri lsp.DocumentUri
function M.get_lsp_diagnostics(uri)
	local cache = lsp_state.doc_cache[uri]
	return cache and cache.diagnostics
end

---@param uri lsp.DocumentUri
---@param key string
---@return PackageInfo|nil
function M.get_lsp_package_info(uri, key)
	local info = M.get_lsp_info(uri)
	return info and info[key]
end

---@param uri lsp.DocumentUri
---@param lines Span
---@return table<string,JsonPackage>
function M.get_lsp_packages(uri, lines)
	local cache = lsp_state.doc_cache[uri]
	local packages = cache and cache.packages
	if not packages then
		return {}
	end

	---@type table<string,JsonPackage>
	local line_packages = {}
	for k, c in pairs(packages) do
		if lines:contains(c.lines.s) or c.lines:contains(lines.s) then
			line_packages[k] = c
		end
	end

	return line_packages
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
