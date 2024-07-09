local state = require("npackages.lsp.state")
local scanner = require("npackages.lsp.scanner")
local analyzer = require("npackages.lsp.analyzer")
local progress = require("npackages.lsp.progress")
local api = require("npackages.lib.api")

local workspace = {}

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
		progress.begin(workDoneToken, "Indexing")

		local res = api.fetch_packages(packages_to_fetch, workDoneToken)
		if res then
			for k, meta in pairs(res) do
				state.api_cache[k] = meta
			end
		end

		progress.finish(workDoneToken)
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
