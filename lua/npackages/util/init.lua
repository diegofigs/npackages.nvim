local job = require("npackages.lib.job")
local loading = require("npackages.ui.loading")
local state = require("npackages.state")
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

---comment
---@param name string
---@return boolean
function M.binary_installed(name)
	if IS_WIN then
		name = name .. ".exe"
	end

	return vim.fn.executable(name) == 1
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

--- Run the given npm script
---@param script_name string
---@param uri string
function M.run_script(script_name, uri)
	local pkg_manager = state.package_manager[vim.uri_to_bufnr(uri)]
	local cmd = pkg_manager .. " run " .. script_name
	local dir = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":h")

	vim.ui.select({ "Confirm", "Cancel" }, {
		prompt = "Run `" .. cmd .. "`",
	}, function(choice)
		if choice == "Confirm" then
			local id = loading.new("| 󰑓 Running " .. script_name)
			job({
				command = cmd,
				cwd = dir,
				on_start = function()
					loading.start(id)
				end,
				on_success = function()
					loading.stop(id)
				end,
				on_error = function()
					loading.stop(id)
				end,
				output = true,
			})
		end
	end)
end

return M
