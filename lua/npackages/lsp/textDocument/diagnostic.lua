local state = require("npackages.lsp.state")
local analyzer = require("npackages.lsp.analyzer")
local progress = require("npackages.lsp.progress")

local M = {}

---Compares document diagnostics' ranges
---@param a lsp.Diagnostic
---@param b lsp.Diagnostic
---@return boolean
local function compare_diagnostics(a, b)
	if a.range.start.line < b.range.start.line then
		return true
	elseif a.range.start.line == b.range.start.line then
		return a.range.start.character < b.range.start.character
	else
		return false
	end
end

---Sorts document symbol tree based on ranges
---@param diagnostics lsp.Diagnostic[]
local function sort_diagnostics(diagnostics)
	table.sort(diagnostics, compare_diagnostics)
end

---@param params lsp.DocumentDiagnosticParams
---@param callback fun(err: lsp.ResponseError?, res: lsp.DocumentDiagnosticReport)
function M.diagnose(params, callback)
	local doc = state.documents[params.textDocument.uri]
	if doc == nil then
		callback(nil, { kind = "unchanged", items = {} })
		return
	end

	local workDoneToken = params.workDoneToken
	progress.begin(workDoneToken, "Diagnostics")

	local doc_cache = state.doc_cache[doc.uri]
	local new_diagnostics = {}
	for k, pkg in pairs(doc_cache.packages) do
		local pkg_metadata = state.api_cache[pkg:package()]

		if pkg.dep_kind == 1 then
			local info, p_diagnostics = analyzer.analyze_package_metadata(pkg, pkg_metadata)
			doc_cache.info[k] = info
			vim.list_extend(new_diagnostics, p_diagnostics)
		end
	end
	state.doc_cache[doc.uri] = doc_cache
	sort_diagnostics(new_diagnostics)

	local prev_diagnostics = state.diagnostics[doc.uri]
	local is_unchanged = vim.deep_equal(prev_diagnostics, new_diagnostics)
	local kind = is_unchanged and "unchanged" or "full"
	state.diagnostics[doc.uri] = new_diagnostics

	local response = { kind = kind, items = new_diagnostics }

	progress.finish(workDoneToken)

	callback(nil, response)
end

return M
