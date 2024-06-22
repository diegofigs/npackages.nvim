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
	-- TODO: read file from doc_cache not editor
	local lines = vim.api.nvim_buf_get_lines(vim.uri_to_bufnr(uri), 0, -1, false)

	local sections, packages = scanner.scan_package_doc(lines)
	local package_set, doc_diagnostics = analyzer.analyze_package_json(sections, packages)
	---@type DocCache
	local doc_cache = {
		packages = package_set,
		diagnostics = doc_diagnostics,
		info = {},
	}
	state.doc_cache[uri] = doc_cache

	local packages_to_fetch = {}
	for _, p in pairs(doc_cache.packages) do
		if p.dep_kind == 1 and p.registry == nil then
			local metadata = state.api_cache[p:package()]
			if not metadata then
				table.insert(packages_to_fetch, p:package())
			end
		end
	end

	if #packages_to_fetch > 0 then
		if workDoneToken then
			progress.begin(workDoneToken, "Indexing")
		end

		local res = api.fetch_packages(packages_to_fetch, workDoneToken)
		if res then
			for k, meta in pairs(res) do
				state.api_cache[k] = meta
			end
		end

		if workDoneToken then
			progress.finish(workDoneToken)
		end
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
