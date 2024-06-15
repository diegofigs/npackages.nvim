local api = require("npackages.api")
local async = require("npackages.async")
local core = require("npackages.lsp.core")
local state = require("npackages.lsp.state")
local util = require("npackages.util")

local function tablelength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

local M = {}

---@param params lsp.DocumentDiagnosticParams
---@return lsp.DocumentDiagnosticReport
local function diagnose(params)
	local doc = state.documents[params.textDocument.uri]
	local buf = vim.uri_to_bufnr(doc.uri)

	local workDoneToken = params.workDoneToken
	---@type lsp.WorkDoneProgressParams
	local begin_params = {
		token = workDoneToken,
		---@type lsp.WorkDoneProgressBegin
		value = {
			kind = "begin",
			title = "Diagnostics",
		},
	}
	state.session.dispatchers.notification(vim.lsp.protocol.Methods.dollar_progress, begin_params)

	local awaited = core.await_throttled_update_if_any(buf)
	if awaited and buf ~= util.current_buf() then
		return {}
	end

	local packages = state.doc_cache[doc.uri].packages
	local _, package_present = next(packages)
	if not package_present then
		return {}
	end

	local pkg_total = tablelength(packages) + 1
	local pkg_count = 1
	for _, pkg in pairs(packages) do
		local api_package = state.api_cache[pkg:package()]
		if not api_package and api.is_fetching_crate(pkg:package()) then
			local _, cancelled = api.await_crate(pkg:package())

			if cancelled or buf ~= util.current_buf() then
				return {}
			end

			packages = state.doc_cache[params.textDocument.uri].packages
			_, pkg = next(packages)
			if not pkg then
				return {}
			end

			api_package = state.api_cache[pkg:package()]
		end

		if not api_package then
			return {}
		end

		---@type lsp.WorkDoneProgressParams
		local progress_params = {
			token = workDoneToken,
			---@type lsp.WorkDoneProgressReport
			value = {
				kind = "report",
				message = string.format("%s/%s packages", pkg_count, pkg_total),
			},
		}
		state.session.dispatchers.notification(vim.lsp.protocol.Methods.dollar_progress, progress_params)
		pkg_count = pkg_count + 1
	end

	local cache = state.doc_cache[doc.uri]

	local prev_diagnostics = state.diagnostics[doc.uri]
	local diagnostics = cache.diagnostics
	state.diagnostics[doc.uri] = diagnostics

	local is_unchanged = vim.deep_equal(prev_diagnostics, diagnostics)
	local kind = is_unchanged and "unchanged" or "full"

	---@type lsp.WorkDoneProgressParams
	local end_params = {
		token = workDoneToken,
		---@type lsp.WorkDoneProgressEnd
		value = {
			kind = "end",
		},
	}
	state.session.dispatchers.notification(vim.lsp.protocol.Methods.dollar_progress, end_params)

	return { kind = kind, items = diagnostics }
end

---@param params lsp.DocumentDiagnosticParams
---@param callback fun(response: lsp.DocumentDiagnosticReport?)
function M.diagnose(params, callback)
	vim.schedule(async.wrap(function()
		callback(diagnose(params))
	end))
end

return M
