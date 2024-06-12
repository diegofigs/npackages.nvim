local state = require("npackages.state")
local types = require("npackages.types")
local MatchKind = types.MatchKind

---@class Ui
---@field custom_diagnostics table<integer,vim.Diagnostic[]>
---@field diagnostics table<integer,vim.Diagnostic[]>
local M = {
	custom_diagnostics = {},
	diagnostics = {},
}

---@alias VimDiagnostic vim.Diagnostic

---@type integer
local CUSTOM_NS = vim.api.nvim_create_namespace("npackages.nvim")
---@type integer
local DIAGNOSTIC_NS = vim.api.nvim_create_namespace("npackages.nvim.diagnostic")

---@param d NpackagesDiagnostic
---@return VimDiagnostic
local function to_vim_diagnostic(d)
	---@type VimDiagnostic
	return {
		lnum = d.lnum,
		end_lnum = d.end_lnum,
		col = d.col,
		end_col = d.end_col,
		severity = d.severity,
		message = state.cfg.diagnostic[d.kind],
		source = "npackages",
	}
end

---comment
---@param buf integer
---@param diagnostics NpackagesDiagnostic[]
function M.display_diagnostics(buf, diagnostics)
	if not state.visible then
		return
	end

	local buf_diagnostics = M.diagnostics[buf] or {}
	for _, d in ipairs(diagnostics) do
		local vim_diagnostic = to_vim_diagnostic(d)
		table.insert(buf_diagnostics, vim_diagnostic)
	end
	M.diagnostics[buf] = buf_diagnostics

	vim.diagnostic.set(DIAGNOSTIC_NS, buf, M.diagnostics[buf])
end

---@param buf integer
---@param info PackageInfo
---@param diagnostics NpackagesDiagnostic[]
function M.display_crate_info(buf, info, diagnostics)
	if not state.visible then
		return
	end

	local buf_diagnostics = M.custom_diagnostics[buf] or {}
	for _, d in ipairs(diagnostics) do
		local vim_diagnostic = to_vim_diagnostic(d)
		table.insert(buf_diagnostics, vim_diagnostic)
	end
	M.custom_diagnostics[buf] = buf_diagnostics

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

	vim.diagnostic.set(CUSTOM_NS, buf, M.custom_diagnostics[buf], { virtual_text = false })
	vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, info.lines.s, info.lines.e)
	vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, info.vers_line, -1, {
		virt_text = virt_text,
		virt_text_pos = "eol",
		hl_mode = "combine",
	})
end

---@param buf integer
---@param info PackageInfo
---@param diagnostics NpackagesDiagnostic[]
function M.display_package_info(buf, info, diagnostics)
	if not state.visible then
		return
	end

	local buf_diagnostics = M.custom_diagnostics[buf] or {}
	for _, d in ipairs(diagnostics) do
		local vim_diagnostic = to_vim_diagnostic(d)
		table.insert(buf_diagnostics, vim_diagnostic)
	end
	M.custom_diagnostics[buf] = buf_diagnostics

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

	vim.diagnostic.set(CUSTOM_NS, buf, M.custom_diagnostics[buf], { virtual_text = false })
	vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, info.lines.s, info.lines.e)
	vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, info.vers_line, -1, {
		virt_text = virt_text,
		virt_text_pos = "eol",
		hl_mode = "combine",
	})
end

---@param buf integer
---@param pkg JsonPackage
function M.display_loading(buf, pkg)
	if not state.visible then
		return
	end

	local virt_text = { { state.cfg.text.loading, state.cfg.highlight.loading } }
	vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, pkg.lines.s, pkg.lines.e)
	local vers_line = pkg.vers and pkg.vers.line or pkg.lines.s
	vim.api.nvim_buf_set_extmark(buf, CUSTOM_NS, vers_line, -1, {
		virt_text = virt_text,
		virt_text_pos = "eol",
		hl_mode = "combine",
	})
end

---@param buf integer
function M.clear(buf)
	M.custom_diagnostics[buf] = nil
	M.diagnostics[buf] = nil

	vim.api.nvim_buf_clear_namespace(buf, CUSTOM_NS, 0, -1)
	vim.diagnostic.reset(CUSTOM_NS, buf)
	vim.diagnostic.reset(DIAGNOSTIC_NS, buf)
end

return M
