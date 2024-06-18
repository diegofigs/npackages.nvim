local state = require("npackages.lsp.state")
local api = require("npackages.lib.api")
local async = require("npackages.lib.async")
local analyzer = require("npackages.lsp.analyzer")
local scanner = require("npackages.lsp.scanner")
local ui = require("npackages.ui")
local util = require("npackages.util")
local DepKind = scanner.DepKind

---@class NpackagesLspCore
---@field throttled_updates table<integer,fun()[]>
---@field inner_throttled_update fun(buf: integer|nil, reload: boolean|nil)
local M = {
	throttled_updates = {},
}

---@type fun(package_name: string, versions: ApiVersion[], version: ApiVersion)
M.reload_deps = async.wrap(function(package_name, versions, version)
	local deps, cancelled = api.fetch_deps(package_name, version.num)
	if cancelled then
		return
	end

	if deps then
		version.deps = deps

		for _, cache in pairs(state.doc_cache) do
			-- INFO: update package in all dependency sections
			for _, pkg in pairs(cache.packages) do
				if pkg:package() == package_name then
					local m, p, y = analyzer.get_newest(versions, pkg:vers_reqs())
					local match = m or p or y

					if pkg.vers and match == version then
						local diagnostics = analyzer.analyze_package_deps(pkg, version, deps)
						vim.list_extend(cache.diagnostics, diagnostics)
					end
				end
			end
		end
	end
end)

---@type fun(package_name: string)
M.reload_package = async.wrap(function(package_name)
	local pkg_metadata, cancelled = api.fetch_crate(package_name)
	local versions = pkg_metadata and pkg_metadata.versions
	if cancelled then
		return
	end

	---@cast versions -nil
	if pkg_metadata and next(versions) then
		state.api_cache[pkg_metadata.name] = pkg_metadata
	end

	for uri, cache in pairs(state.doc_cache) do
		local buf = vim.uri_to_bufnr(uri)
		-- INFO: update package in all dependency sections
		for k, pkg in pairs(cache.packages) do
			if pkg.dep_kind == DepKind.REGISTRY and pkg.registry == nil then
				if pkg:package() == package_name then
					local info, diagnostics = analyzer.analyze_package_metadata(pkg, pkg_metadata)
					cache.info[k] = info
					vim.list_extend(cache.diagnostics, diagnostics)

					ui.display_package_info(buf, info)

					local version = info.vers_match or info.vers_upgrade
					if version then
						M.reload_deps(pkg:package(), versions, version)
					end
				end
			end
		end
	end
end)

---@param uri lsp.DocumentUri
---@param reload boolean|nil
local function update(uri, reload)
	-- local doc = state.documents[uri]
	local buf = vim.uri_to_bufnr(uri)

	if reload then
		state.api_cache = {}
		api.cancel_jobs()
	end

	-- TODO: read file from doc_cache not editor
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	local sections, packages = scanner.scan_package_doc(lines)
	local package_set, diagnostics = analyzer.analyze_package_json(sections, packages)
	local cache = {
		packages = package_set,
		info = {},
		diagnostics = diagnostics,
	}
	state.doc_cache[uri] = cache

	ui.clear(buf)
	for cache_key, pkg in pairs(package_set) do
		if pkg.dep_kind == DepKind.REGISTRY and pkg.registry == nil then
			local api_package = state.api_cache[pkg:package()]
			local versions = api_package and api_package.versions

			if not reload and api_package then
				local info, p_diagnostics = analyzer.analyze_package_metadata(pkg, api_package)
				cache.info[cache_key] = info
				vim.list_extend(cache.diagnostics, p_diagnostics)

				ui.display_package_info(buf, info)

				local version = info.vers_match or info.vers_upgrade
				if version then
					if version.deps then
						local d_diagnostics = analyzer.analyze_package_deps(pkg, version, version.deps)
						vim.list_extend(cache.diagnostics, d_diagnostics)
					else
						M.reload_deps(pkg:package(), versions, version)
					end
				end
			else
				M.reload_package(pkg:package())
			end
		end
	end

	local callbacks = M.throttled_updates[buf]
	if callbacks then
		for _, callback in ipairs(callbacks) do
			callback()
		end
	end
	M.throttled_updates[buf] = nil

	return cache
end

---@param buf integer|nil
---@param reload boolean|nil
function M.throttled_update(buf, reload)
	buf = buf or util.current_buf()
	local existing = M.throttled_updates[buf]
	if not existing then
		M.throttled_updates[buf] = {}
	end

	M.inner_throttled_update(buf, reload)
end

---@param buf integer
---@return boolean
function M.await_throttled_update_if_any(buf)
	local existing = M.throttled_updates[buf]
	if not existing then
		return false
	end

	---@param resolve fun()
	coroutine.yield(function(resolve)
		table.insert(existing, resolve)
	end)

	return true
end

---@param uri lsp.DocumentUri
function M.update(uri)
	return update(uri, false)
end

---@param uri lsp.DocumentUri
function M.reload(uri)
	return update(uri, true)
end

return M
