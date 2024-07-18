local nio = require("nio")
local state = require("npackages.lsp.state")
local scanner = require("npackages.lsp.scanner")
local analyzer = require("npackages.lsp.analyzer")
local progress = require("npackages.lsp.progress")
local api = require("npackages.lib.api")

local workspace = {}

---@async
---@param package_names string[]
---@param workDoneToken? lsp.ProgressToken
local function fetch_packages(package_names, workDoneToken)
	local functions = {}
	local pkg_total = #package_names
	local pkg_count = 0
	for _, package_name in ipairs(package_names) do
		table.insert(functions, function()
			local res = api.curl_package(package_name)
			local metadata = nio.fn.json_decode(res)
			local pkg_metadata = api.parse_metadata(metadata)
			state.api_cache[pkg_metadata.name] = pkg_metadata

			pkg_count = pkg_count + 1
			nio.scheduler()
			progress.report(
				workDoneToken,
				string.format("%s/%s packages", pkg_count, pkg_total),
				math.floor(pkg_count / pkg_total * 100)
			)
			return pkg_metadata
		end)
	end
	return nio.gather(functions)
end

---@async
---@param uri lsp.DocumentUri
---@param workDoneToken lsp.ProgressToken
workspace.refresh = function(uri, workDoneToken)
	local sections, packages, scripts = scanner.scan_package_doc(vim.split(state.documents[uri].text, "\n"))
	local section_set, package_set, doc_diagnostics = analyzer.analyze_package_json(sections, packages)
	---@type DocCache
	local doc_cache = {
		sections = section_set,
		packages = package_set,
		scripts = scripts,
		diagnostics = doc_diagnostics,
		info = {},
	}
	state.doc_cache[uri] = doc_cache

	local packages_to_fetch = {}
	for _, p in pairs(doc_cache.packages) do
		if p.dep_kind == 1 then
			local metadata = state.api_cache[p:package()]
			if not metadata then
				table.insert(packages_to_fetch, p:package())
			end
		end
	end

	if #packages_to_fetch > 0 then
		fetch_packages(packages_to_fetch, workDoneToken)
	end
end

---@async
---@param uri lsp.DocumentUri
---@param workDoneToken lsp.ProgressToken
workspace.reload = function(uri, workDoneToken)
	state.api_cache = {}

	workspace.refresh(uri, workDoneToken)
end

return workspace
