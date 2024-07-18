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
	session = {
		task_queue = {},
	},
}

---@class DocCache
---@field packages table<string,JsonPackage>
---@field sections table<string,JsonSection>
---@field scripts table<string,JsonScript>
---@field info table<string,PackageInfo>

---@class PackageInfo
---@field range lsp.Range
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
---@field task_queue nio.tasks.Task[]

---@class ApiPackageSummary
---@field name string
---@field description string
---@field newest_version string

---@class PackageMetadata
---@field name string
---@field description string
---@field created DateTime
---@field updated DateTime
---@field homepage string|nil
---@field repository string|nil
---@field keywords string[]
---@field versions ApiVersion[]

---@class ApiVersion
---@field num string
---@field parsed SemVer
---@field created DateTime
---@field dependencies PackageRequirement[]
---@field devDependencies PackageRequirement[]

---@class PackageRequirement
---@field name string
---@field version string

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
---local ApiDependencyKind = {
---	NORMAL = 1,
---	DEV = 2,
---	PEER = 3,
---}

return State
