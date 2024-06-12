local async = require("npackages.async")
local state = require("npackages.lsp.state")
local cfg = require("npackages.state").cfg
local get_dependency_name_from_line = require("npackages.utils.get_dependency_name_from_line")
local core = require("npackages.lsp.core")
local logger = require("npackages.logger")

local textDocument = {}

---@param d NpackagesDiagnostic
---@return lsp.Diagnostic
local function to_lsp_diagnostic(d)
	---@type lsp.Diagnostic
	return {
		range = {
			start = { line = d.lnum, character = d.col },
			["end"] = { line = d.end_lnum, character = d.end_col },
		},
		severity = d.severity,
		message = cfg.diagnostic[d.kind],
		source = "npackages",
	}
end

---@param params lsp.DidOpenTextDocumentParams
---@param callback fun(diagnostics: lsp.Diagnostic[])
function textDocument.didOpen(params, callback)
	local doc = params.textDocument
	state.documents[doc.uri] = doc

	local cache = core.update(doc.uri)
	-- initialize the throttled update function with timeout
	core.inner_throttled_update = async.throttle(function()
		core.update(doc.uri)
	end, cfg.autoupdate_throttle)

	-- compute diagnostics
	local diagnostics = {}
	for _, d in ipairs(cache.diagnostics) do
		table.insert(diagnostics, to_lsp_diagnostic(d))
	end

	callback(diagnostics)
end

---@param params lsp.DidChangeTextDocumentParams
---@param callback fun(diagnostics: lsp.Diagnostic[])
function textDocument.didChange(params, callback)
	local doc = params.textDocument
	for _, change in ipairs(params.contentChanges) do
		state.documents[doc.uri].text = change.text
	end

	local cache = core.update(doc.uri)
	-- core.throttled_update(nil, false)

	-- compute diagnostics
	local diagnostics = {}
	for _, d in ipairs(cache.diagnostics) do
		table.insert(diagnostics, to_lsp_diagnostic(d))
	end

	callback(diagnostics)
end

---@param params lsp.DidCloseTextDocumentParams
function textDocument.didClose(params)
	local doc = params.textDocument
	state.documents[doc.uri] = nil
end

---@param params lsp.HoverParams
---@return lsp.Hover?
function textDocument.hover(params)
	local doc = state.documents[params.textDocument.uri]

	local lines = {}
	for s in doc.text:gmatch("[^\r\n]+") do
		table.insert(lines, s)
	end

	local line = lines[params.position.line + 1] -- 1-based index on lists

	local package_name = get_dependency_name_from_line(line)
	logger.info(package_name)

	if package_name then
		return { contents = { kind = "plaintext", value = package_name } }
	end
end

---@param params lsp.DocumentDiagnosticParams
---@param callback fun(result: lsp.DocumentDiagnosticReport)
function textDocument.diagnostic(params, callback)
	local doc = state.documents[params.textDocument.uri]

	-- parse document
	local lines = {}
	for s in doc.text:gmatch("[^\r\n]+") do
		table.insert(lines, s)
	end

	local cache = core.reload(doc.uri)

	-- compute diagnostics
	---@type lsp.Diagnostic[]
	local diagnostics = {}
	for _, d in ipairs(cache.diagnostics) do
		table.insert(diagnostics, to_lsp_diagnostic(d))
	end
	callback({ kind = "full", items = diagnostics })
end

return textDocument
