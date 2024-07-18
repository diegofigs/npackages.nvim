local state = require("npackages.state")

local M = {
	marks = {},
}

local mark_ns = vim.api.nvim_create_namespace("npackages.nvim")

---@param buf integer
---@param infos table<string, PackageInfo>
M.display = function(buf, infos)
	if not state.visible then
		return
	end

	-- Cache current package names
	local current_pkg_names = {}
	for pkg_name, info in pairs(infos) do
		current_pkg_names[pkg_name] = true

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

		-- vim.api.nvim_buf_clear_namespace(buf, mark_ns, info.range.start.line, info.range["end"].line)
		local existing_mark = M.marks[pkg_name]
		local mark_id = vim.api.nvim_buf_set_extmark(buf, mark_ns, info.range.start.line, -1, {
			id = existing_mark,
			virt_text = virt_text,
			virt_text_pos = "eol",
			hl_mode = "combine",
		})
		if not existing_mark then
			M.marks[pkg_name] = mark_id
		end
	end

	-- Remove extmarks for packages that are no longer present in the infos array
	for pkg_name, mark_id in pairs(M.marks) do
		if not current_pkg_names[pkg_name] then
			vim.api.nvim_buf_del_extmark(buf, mark_ns, mark_id)
			M.marks[pkg_name] = nil
		end
	end
end

---@param buf integer
function M.clear(buf)
	vim.api.nvim_buf_clear_namespace(buf, mark_ns, 0, -1)
	M.marks = {}
end

return M
