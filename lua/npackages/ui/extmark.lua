local state = require("npackages.state")

local M = {}

local mark_ns = vim.api.nvim_create_namespace("npackages.nvim")

---@param buf integer
---@param infos PackageInfo[]
M.display = function(buf, infos)
	if not state.visible then
		return
	end

	for _, info in pairs(infos) do
		local virt_text = {}
		if info.vers_match then
			table.insert(virt_text, {
				string.format(state.cfg.text[info.match_kind], info.vers_match.num),
				state.cfg.highlight[info.match_kind],
			})
		elseif info.match_kind == "nomatch" then
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

		vim.api.nvim_buf_clear_namespace(buf, mark_ns, info.lines.s, info.lines.e)
		vim.api.nvim_buf_set_extmark(buf, mark_ns, info.vers_line, -1, {
			virt_text = virt_text,
			virt_text_pos = "eol",
			hl_mode = "combine",
		})
	end
end

---@param buf integer
function M.clear(buf)
	vim.api.nvim_buf_clear_namespace(buf, mark_ns, 0, -1)
end

return M
