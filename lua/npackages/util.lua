local semver = require("npackages.semver")
local state = require("npackages.state")
local types = require("npackages.types")
local Span = types.Span

local M = {}

local IS_WIN = vim.api.nvim_call_function("has", { "win32" }) == 1

---@return integer
function M.current_buf()
	return vim.api.nvim_get_current_buf()
end

---@return integer, integer
function M.cursor_pos()
	---@type integer[]
	local cursor = vim.api.nvim_win_get_cursor(0)
	return cursor[1] - 1, cursor[2]
end

---@return Span
function M.selected_lines()
	local info = vim.api.nvim_get_mode()
	if info.mode:match("[vV]") then
		---@type integer
		local s = vim.fn.getpos("v")[2]
		---@type integer
		local e = vim.fn.getcurpos()[2]
		return Span.new(s, e)
	else
		local s = vim.api.nvim_buf_get_mark(0, "<")[1]
		local e = vim.api.nvim_buf_get_mark(0, ">")[1]
		return Span.new(s, e)
	end
end

---@param buf integer
---@return table<string, PackageInfo>|nil
function M.get_buf_info(buf)
	local cache = state.buf_cache[buf]
	return cache and cache.info
end

---@param buf integer
---@return NpackagesDiagnostic[]|nil
function M.get_buf_diagnostics(buf)
	local cache = state.buf_cache[buf]
	return cache and cache.diagnostics
end

---@param buf integer
---@param key string
---@return PackageInfo|nil
function M.get_package_info(buf, key)
	local info = M.get_buf_info(buf)
	return info and info[key]
end

---@param buf integer
---@param lines Span
---@return table<string,JsonPackage>
function M.get_line_packages(buf, lines)
	local cache = state.buf_cache[buf]
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

---@param versions ApiVersion[]|nil
---@param reqs Requirement[]|nil
---@return ApiVersion|nil
---@return ApiVersion|nil
---@return ApiVersion|nil
function M.get_newest(versions, reqs)
	if not versions or not next(versions) then
		return nil
	end

	local allow_pre = reqs and semver.allows_pre(reqs) or false

	---@type ApiVersion|nil, ApiVersion|nil
	local newest_pre, newest

	for _, v in ipairs(versions) do
		if not reqs or semver.matches_requirements(v.parsed, reqs) then
			-- if not v.yanked then
			if allow_pre or not v.parsed.pre then
				newest = v
				break
			else
				newest_pre = newest_pre or v
			end
			-- else
			-- 	newest_yanked = newest_yanked or v
			-- end
		end
	end

	return newest, newest_pre
end

---@param name string
---@return boolean
function M.lualib_installed(name)
	local ok = pcall(require, name)
	return ok
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

	M.notify(vim.log.levels.WARN, "Couldn't open url")
end

---@param name string
---@return string
function M.format_title(name)
	return name:sub(1, 1):upper() .. name:gsub("_", " "):sub(2)
end

return M
