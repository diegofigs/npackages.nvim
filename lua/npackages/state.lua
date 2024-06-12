---@class State
---@field cfg Config
-- api cache structure
---@field api_cache table<string,ApiPackage>
---@field buf_cache table<integer,BufCache>
---@field search_cache SearchCache
---@field visible boolean
-- npm metadata
---@field has_old_yarn boolean
---@field package_manager table<integer,string>
local State = {
	api_cache = {},
	buf_cache = {},
	search_cache = {
		results = {},
		searches = {},
	},
	--- npm related
	--- If true the project is using yarn 2<
	has_old_yarn = false,
	package_manager = {},
}

---@class BufCache
---@field packages table<string,JsonPackage>
---@field info table<string,PackageInfo>
---@field diagnostics NpackagesDiagnostic[]

---@class SearchCache
---@field searches table<string, string[]>
---@field results table<string, ApiPackageSummary>

return State
