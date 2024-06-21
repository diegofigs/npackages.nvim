local state = require("npackages.lsp.state")
local analyzer = require("npackages.lsp.analyzer")
local progress = require("npackages.lsp.progress")

local M = {}

---@param params lsp.DocumentDiagnosticParams
---@param callback fun(err, res: lsp.DocumentDiagnosticReport)
function M.diagnose(params, callback)
	local doc = state.documents[params.textDocument.uri]
	if doc == nil then
		callback(nil, { kind = "unchanged", items = {} })
		return
	end

	local workDoneToken = params.workDoneToken or "1"
	progress.begin(workDoneToken, "Diagnostics")

	local doc_cache = state.doc_cache[doc.uri]
	for k, pkg in pairs(doc_cache.packages) do
		local pkg_metadata = state.api_cache[pkg:package()]

		if pkg_metadata then
			if pkg.dep_kind == 1 and pkg.registry == nil then
				local info, p_diagnostics = analyzer.analyze_package_metadata(pkg, pkg_metadata)
				doc_cache.info[k] = info
				vim.list_extend(doc_cache.diagnostics, p_diagnostics)
			end
		end
	end
	state.doc_cache[doc.uri] = doc_cache

	local prev_diagnostics = state.diagnostics[doc.uri]
	local new_diagnostics = doc_cache.diagnostics
	local is_unchanged = vim.deep_equal(prev_diagnostics, new_diagnostics)
	local kind = is_unchanged and "unchanged" or "full"
	state.diagnostics[doc.uri] = new_diagnostics

	local response = { kind = kind, items = new_diagnostics }

	progress.finish(workDoneToken)

	callback(nil, response)
end

return M
