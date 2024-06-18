local state = require("npackages.state")
local analyzer = require("npackages.lsp.analyzer")
local MatchKind = analyzer.MatchKind

local M = {}

local CUSTOM_NS = vim.api.nvim_create_namespace("npackages.nvim")

---@param buf integer
---@param info PackageInfo
function M.display_package_info(buf, info)
	if not state.visible then
		return
	end

	local virt_text = {}
	if info.vers_match then
		table.insert(virt_text, {
			string.format(state.cfg.text[info.match_kind], info.vers_match.num),
			state.cfg.highlight[info.match_kind],
		})
	elseif info.match_kind == MatchKind.NOMATCH then
		table.insert(virt_text, {
			state.cfg.text.nomatch,
			state.cfg.highlight.nomatch,
		})
	end
	if info.vers_upgrade then
		table.insert(virt_text, {
			string.format(state.cfg.text.upgrade, info.vers_upgrade.num),
			state.cfg.highlight.upgrade,
		})
	end

	if not (info.vers_match or info.vers_upgrade) then
		table.insert(virt_text, {
			state.cfg.text.error,
			state.cfg.highlight.error,
		})
	end

	vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, info.lines.s, info.lines.e)
	vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, info.vers_line, -1, {
		virt_text = virt_text,
		virt_text_pos = "eol",
		hl_mode = "combine",
	})
end

---@param buf integer
function M.clear(buf)
	vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, 0, -1)
	vim.diagnostic.reset(CUSTOM_NS, buf)
end

return M
