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

---@class ApiPackageSummary
---@field name string
---@field description string
---@field newest_version string

---@class PackageMetadata
---@field name string
---@field description string
---@field created DateTime
---@field updated DateTime
-- ---@field downloads integer
---@field homepage string|nil
---@field repository string|nil
-- ---@field documentation string|nil
-- ---@field categories string[]
---@field keywords string[]
---@field versions ApiVersion[]

---@class ApiVersion
---@field num string
---@field parsed SemVer
---@field created DateTime
---@field deps ApiDependency[]|nil

---@class ApiDependency
---@field name string
---@field opt boolean
---@field kind ApiDependencyKind
---@field vers ApiDependencyVers

---@class ApiDependencyVers
---@field reqs Requirement[]
---@field text string

---@class Requirement
---@field cond Cond
---@field cond_col Span
---@field vers SemVer
---@field vers_col Span

---@enum ApiDependencyKind
---@diagnostic disable-next-line: unused-local
local ApiDependencyKind = {
	NORMAL = 1,
	DEV = 2,
	PEER = 3,
}

return State
