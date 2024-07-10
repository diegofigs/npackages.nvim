local M = {}

local highlights = {
	{ "NpackagesNvimLoading", { default = true, link = "DiagnosticVirtualTextInfo" } },
	{ "NpackagesNvimLatest", { default = true, link = "DiagnosticVirtualTextOk" } },
	{ "NpackagesNvimVersion", { default = true, link = "DiagnosticVirtualTextInfo" } },
	{ "NpackagesNvimPreRelease", { default = true, link = "DiagnosticVirtualTextError" } },
	{ "NpackagesNvimYanked", { default = true, link = "DiagnosticVirtualTextError" } },
	{ "NpackagesNvimNoMatch", { default = true, link = "DiagnosticVirtualTextError" } },
	{ "NpackagesNvimUpgrade", { default = true, link = "DiagnosticVirtualTextWarn" } },
	{ "NpackagesNvimError", { default = true, link = "DiagnosticVirtualTextError" } },

	{ "NpackagesNvimPopupTitle", { default = true, link = "Title" } },
	{
		"NpackagesNvimPopupPillText",
		{ default = true, ctermfg = 15, ctermbg = 242, fg = "#e0e0e0", bg = "#3a3a3a" },
	},
	{ "NpackagesNvimPopupPillBorder", { default = true, ctermfg = 242, fg = "#3a3a3a" } },
	{ "NpackagesNvimPopupDescription", { default = true, link = "Comment" } },
	{ "NpackagesNvimPopupLabel", { default = true, link = "Identifier" } },
	{ "NpackagesNvimPopupValue", { default = true, link = "String" } },
	{ "NpackagesNvimPopupUrl", { default = true, link = "Underlined" } },
	{ "NpackagesNvimPopupVersion", { default = true, link = "None" } },
	{ "NpackagesNvimPopupPreRelease", { default = true, link = "DiagnosticVirtualTextWarn" } },
	{ "NpackagesNvimPopupYanked", { default = true, link = "DiagnosticVirtualTextError" } },
	{ "NpackagesNvimPopupVersionDate", { default = true, link = "Comment" } },
	{ "NpackagesNvimPopupFeature", { default = true, link = "None" } },
	{ "NpackagesNvimPopupEnabled", { default = true, ctermfg = 2, fg = "#23ab49" } },
	{ "NpackagesNvimPopupTransitive", { default = true, ctermfg = 4, fg = "#238bb9" } },
	{ "NpackagesNvimPopupNormalDependenciesTitle", { default = true, link = "Statement" } },
	{ "NpackagesNvimPopupBuildDependenciesTitle", { default = true, link = "Statement" } },
	{ "NpackagesNvimPopupDevDependenciesTitle", { default = true, link = "Statement" } },
	{ "NpackagesNvimPopupDependency", { default = true, link = "None" } },
	{ "NpackagesNvimPopupOptional", { default = true, link = "Comment" } },
	{ "NpackagesNvimPopupDependencyVersion", { default = true, link = "String" } },
	{ "NpackagesNvimPopupLoading", { default = true, link = "Special" } },

	{ "CmpItemKindVersion", { default = true, link = "Special" } },
	{ "CmpItemKindPackage", { default = true, link = "Special" } },
}

function M.create_highlights()
	for _, h in ipairs(highlights) do
		local hl_name = h[1]
		local hl = h[2]
		vim.api.nvim_set_hl(0, hl_name, hl)
	end
end

return M
