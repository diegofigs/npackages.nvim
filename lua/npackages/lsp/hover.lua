local state = require("npackages.lsp.state")
local get_dependency_name_from_line = require("npackages.util.get_dependency_name_from_line")
local util = require("npackages.util")

local M = {}

---@param items string[]
local function kw_to_text(items)
	local hl_text = ""
	for _, kw in ipairs(items) do
		hl_text = hl_text .. "*" .. kw .. "*" .. " "
	end
	return hl_text
end

local text = {
	created_label = " created        ",
	updated_label = " updated        ",
	homepage_label = " homepage       ",
	repository_label = " repository     ",
	registry_label = " npmjs.com      ",
	keywords_label = " keywords       ",
}

---@param params lsp.HoverParams
---@return lsp.Hover?
function M.hover(params)
	local doc = state.documents[params.textDocument.uri]
	local buf = vim.uri_to_bufnr(doc.uri)

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local line = lines[params.position.line + 1] -- 1-based index on lists

	local package_name = get_dependency_name_from_line(line)
	if package_name then
		local pkg = state.api_cache[package_name]

		local title = "# " .. string.format(text.title, pkg.name)
		local hover_text = title .. "\n"

		if pkg.description then
			local desc = pkg.description:gsub("\r", "\n")
			local desc_lines = vim.split(desc, "\n")
			for _, l in ipairs(desc_lines) do
				if l ~= "" then
					hover_text = hover_text .. "\n" .. string.format("%s", l)
				end
			end
			hover_text = hover_text .. "\n"
		end

		local date_format = "%Y-%m-%d"
		if pkg.created then
			hover_text = hover_text .. "\n## " .. text.created_label
			hover_text = hover_text .. " " .. string.format("%s", pkg.created:display(date_format))
		end

		if pkg.updated then
			hover_text = hover_text .. "\n## " .. text.updated_label
			hover_text = hover_text .. " " .. string.format("%s", pkg.updated:display(date_format))
		end

		if pkg.homepage then
			hover_text = hover_text .. "\n## " .. text.homepage_label
			hover_text = hover_text .. " " .. string.format("[%s](%s)", pkg.homepage, pkg.homepage)
		end

		if pkg.repository then
			hover_text = hover_text .. "\n## " .. text.repository_label
			hover_text = hover_text .. " " .. string.format("[%s](%s)", pkg.repository, pkg.repository)
		end

		hover_text = hover_text .. "\n## " .. text.registry_label
		local pkg_url = util.package_url(pkg.name)
		hover_text = hover_text .. " " .. string.format("[%s](%s)", pkg_url, pkg_url)

		if next(pkg.keywords) then
			hover_text = hover_text .. "\n## " .. text.keywords_label
			hover_text = hover_text .. " " .. kw_to_text(pkg.keywords)
		end

		---@type lsp.Hover
		return { contents = { kind = "markdown", value = hover_text } }
	end
end

return M
