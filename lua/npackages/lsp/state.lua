local State = {
	---@type table<lsp.DocumentUri, lsp.TextDocumentItem>
	documents = {},
	---@type table<lsp.DocumentUri, lsp.Diagnostic[]>
	diagnostics = {},
	---@type table<lsp.DocumentUri, DocCache>
	doc_cache = {},
	---@type table<string, ApiPackage>
	api_cache = {},
	---@type SearchCache
	search_cache = {
		searches = {},
		results = {},
	},
	---@type table<lsp.DocumentUri, string>
	wdt_cache = {},
}

---@class DocCache
---@field packages table<string,JsonPackage>
---@field info table<string,PackageInfo>
---@field diagnostics NpackagesDiagnostic[]

return State
