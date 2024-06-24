local analyzer = require("npackages.lsp.analyzer")
local hover = require("npackages.hover.common")
local state = require("npackages.state")
local util = require("npackages.util")

local M = {}

---@param buf integer
---@param package JsonPackage
---@param text string
local function insert_version(buf, package, text)
	local t = text
	if state.cfg.insert_closing_quote and not package.vers.quote.e then
		t = text .. package.vers.quote.s
	end
	local line = package.vers.range.start.line

	vim.api.nvim_buf_set_text(
		buf,
		line,
		package.vers.range.start.character,
		line,
		package.vers.range["end"].character,
		{ t }
	)
end

---@param buf integer
---@param package JsonPackage
---@param version SemVer
---@param alt boolean|nil
local function set_version(buf, package, version, alt)
	local text = analyzer.version_text(package, version, alt)
	insert_version(buf, package, text)
end

---@class VersContext
---@field buf integer
---@field crate JsonPackage
---@field versions ApiVersion[]

---@param ctx VersContext
---@param line integer
---@param alt boolean|nil
local function select_version(ctx, line, alt)
	local index = hover.item_index(line)
	local crate = ctx.crate
	local version = ctx.versions[index]
	if not version then
		return
	end

	set_version(ctx.buf, crate, version.parsed, alt)

	if state.cfg.popup.hide_on_select then
		hover.hide()
	end
end

---@param versions ApiVersion[]
---@param line integer
local function copy_version(versions, line)
	local index = hover.item_index(line)
	local version = versions[index]
	if not version then
		return
	end

	vim.fn.setreg(state.cfg.popup.copy_register, version.num)
end

---@param crate JsonPackage
---@param versions ApiVersion[]
---@param opts WinOpts
function M.open(crate, versions, opts)
	hover.type = hover.Type.VERSIONS

	local title = string.format(state.cfg.popup.text.title, crate:package())
	local vers_width = 0
	---@type HighlightText[][]
	local versions_text = {}

	for _, v in ipairs(versions) do
		---@type string, string
		local text, hl
		-- if v.yanked then
		-- 	text = string.format(state.cfg.popup.text.yanked, v.num)
		-- 	hl = state.cfg.popup.highlight.yanked
		if v.parsed.pre then
			text = string.format(state.cfg.popup.text.prerelease, v.num)
			hl = state.cfg.popup.highlight.prerelease
		else
			text = string.format(state.cfg.popup.text.version, v.num)
			hl = state.cfg.popup.highlight.version
		end
		---@type HighlightText
		local t = { text = text, hl = hl }

		table.insert(versions_text, { t })
		vers_width = math.max(vim.fn.strdisplaywidth(t.text), vers_width)
	end

	local date_width = 0
	if state.cfg.popup.show_version_date then
		for i, line in ipairs(versions_text) do
			local vers_text = line[1]
			---@type integer
			local diff = vers_width - vim.fn.strdisplaywidth(vers_text.text)
			local date = versions[i].created:display(state.cfg.date_format)
			vers_text.text = vers_text.text .. string.rep(" ", diff)

			---@type HighlightText
			local date_text = {
				text = string.format(state.cfg.popup.text.version_date, date),
				hl = state.cfg.popup.highlight.version_date,
			}
			table.insert(line, date_text)
			date_width = math.max(vim.fn.strdisplaywidth(date_text.text), date_width)
		end
	end

	local width = hover.win_width(title, vers_width + date_width)
	local height = hover.win_height(versions)
	---@param _win integer
	---@param buf integer
	hover.open_win(width, height, title, versions_text, opts, function(_win, buf)
		local ctx = {
			buf = util.current_buf(),
			crate = crate,
			versions = versions,
		}
		for _, k in ipairs(state.cfg.popup.keys.select) do
			vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
				callback = function()
					local line = util.cursor_pos()
					select_version(ctx, line)
				end,
				noremap = true,
				silent = true,
				desc = "Select version",
			})
		end

		for _, k in ipairs(state.cfg.popup.keys.select_alt) do
			vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
				callback = function()
					local line = util.cursor_pos()
					select_version(ctx, line, true)
				end,
				noremap = true,
				silent = true,
				desc = "Select version alt",
			})
		end

		for _, k in ipairs(state.cfg.popup.keys.copy_value) do
			vim.api.nvim_buf_set_keymap(buf, "n", k, "", {
				callback = function()
					local line = util.cursor_pos()
					copy_version(versions, line)
				end,
				noremap = true,
				silent = true,
				desc = "Copy version",
			})
		end
	end)
end

return M
