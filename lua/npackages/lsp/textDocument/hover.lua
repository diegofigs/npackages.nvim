local state = require("npackages.lsp.state")
local npm = require("npackages.lib.npm")
local semver = require("npackages.lib.semver")

local M = {}

---@param items string[]
---@return string
local function kw_to_text(items)
	local hl_text = ""
	for _, kw in ipairs(items) do
		hl_text = hl_text .. "*" .. kw .. "*" .. " "
	end
	return hl_text
end

---Trim surrounding whitespace from string value
---@param s string
---@return string
local function trim(s)
	return vim.trim(s)
end

---@param deps PackageRequirement[]
---@return string
local function deps_to_text(deps)
	local deps_text = ""
	for _, dep in ipairs(deps) do
		deps_text = deps_text .. string.format("- **%s**: `%s`\n", dep.name, dep.version)
	end
	return deps_text
end

local text = {
	title = " %s",
	created_label = " created        ",
	updated_label = " updated        ",
	homepage_label = " homepage       ",
	repository_label = " repository     ",
	registry_label = " npmjs.com      ",
	keywords_label = " keywords       ",
	dependencies_label = "  dependencies",
	devDependencies_label = " devDependencies",
}

---@param params lsp.HoverParams
---@return lsp.Hover?
function M.hover(params)
	local doc = state.documents[params.textDocument.uri]
	local buf = vim.uri_to_bufnr(doc.uri)

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local line = lines[params.position.line + 1] -- 1-based index on lists

	local package_name, specified_version = npm.get_dependency_from_line(line)
	if package_name and specified_version then
		local pkg = state.api_cache[package_name]
		if not pkg then
			return
		end

		-- Find the specific version details
		local version_info
		local requirement = semver.parse_requirement(specified_version)
		for _, version in pairs(pkg.versions) do
			if semver.matches_requirement(version.parsed, requirement) then
				version_info = version
				break
			end
		end

		if not version_info then
			return
		end

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
			hover_text = trim(hover_text)
		end

		hover_text = hover_text .. "\n\n## Metadata\n"

		local date_format = "%Y-%m-%d"
		if pkg.created then
			hover_text = hover_text .. "\n- " .. text.created_label
			hover_text = hover_text .. " " .. trim(string.format("%s", pkg.created:display(date_format)))
		end

		if pkg.updated then
			hover_text = hover_text .. "\n- " .. text.updated_label
			hover_text = hover_text .. " " .. trim(string.format("%s", pkg.updated:display(date_format)))
		end

		if pkg.homepage then
			hover_text = hover_text .. "\n- " .. text.homepage_label
			hover_text = hover_text .. " " .. trim(string.format("[%s](%s)", pkg.homepage, pkg.homepage))
		end

		if pkg.repository then
			hover_text = hover_text .. "\n- " .. text.repository_label
			hover_text = hover_text .. " " .. trim(string.format("[%s](%s)", pkg.repository, pkg.repository))
		end

		hover_text = hover_text .. "\n- " .. text.registry_label
		local pkg_url = npm.package_url(pkg.name)
		hover_text = hover_text .. " " .. trim(string.format("[%s](%s)", pkg_url, pkg_url))

		if next(pkg.keywords) then
			hover_text = hover_text .. "\n- " .. text.keywords_label
			hover_text = hover_text .. " " .. kw_to_text(pkg.keywords)
		end

		-- Add dependencies and dev dependencies for the specific version
		if version_info.dependencies and next(version_info.dependencies) then
			hover_text = trim(hover_text) .. "\n\n## " .. text.dependencies_label
			hover_text = hover_text .. "\n\n" .. deps_to_text(version_info.dependencies)
		end

		if version_info.devDependencies and next(version_info.devDependencies) then
			hover_text = trim(hover_text) .. "\n\n## " .. text.devDependencies_label
			hover_text = hover_text .. "\n\n" .. deps_to_text(version_info.devDependencies)
		end

		return { contents = { kind = "markdown", value = hover_text } }
	end
end

return M
