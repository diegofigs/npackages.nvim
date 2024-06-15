local State = {
	---@type table<lsp.DocumentUri, lsp.TextDocumentItem>
	documents = {},
	---@type table<lsp.DocumentUri, lsp.Diagnostic[]>
	diagnostics = {},
	---@type table<lsp.DocumentUri, DocCache>
	doc_cache = {},
	---@type table<string, PackageMetadata>
	api_cache = {},
	---@type SearchCache
	search_cache = {
		searches = {},
		results = {},
	},
	---@class LspSession
	session = {},
}

---@class DocCache
---@field packages table<string,JsonPackage>
---@field info table<string,PackageInfo>
---@field diagnostics lsp.Diagnostic[]

---@class PackageInfo
---@field lines Span
---@field vers_line integer
---@field vers_match ApiVersion|nil
---@field vers_update ApiVersion|nil
---@field vers_upgrade ApiVersion|nil
---@field match_kind MatchKind

---@class SearchCache
---@field searches table<string, string[]>
---@field results table<string, ApiPackageSummary>

---@class LspSession
---@field client_id integer
---@field dispatchers vim.lsp.rpc.Dispatchers

return State
