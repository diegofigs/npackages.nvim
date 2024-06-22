local nio = require("nio")
local progress = require("npackages.lsp.progress")
local time = require("npackages.lib.time")
local semver = require("npackages.lib.semver")
local DateTime = time.DateTime

local api = {}

local REGISTRY = "https://registry.npmjs.org"
local USERAGENT = vim.fn.shellescape("npackages.nvim (https://github.com/diegofigs/npackages.nvim)")

---Maps a metadata table to PackageMetadata
---@param decoded table
---@return PackageMetadata
api.parse_metadata = function(decoded)
	---@type table<string,any>
	local metadata = decoded

	---@type PackageMetadata
	local package = {
		name = metadata.name,
		description = assert(metadata.description),
		created = assert(DateTime.parse_iso_8601(metadata.time.created)),
		updated = assert(DateTime.parse_iso_8601(metadata.time.modified)),
		-- downloads = assert(p.downloads),
		homepage = metadata.homepage,
		-- documentation = p.documentation,
		repository = metadata.repository and metadata.repository.url and metadata.repository.url:match(
			"^.*%+(.*)%..*$"
		),
		categories = {},
		keywords = metadata.keywords or {},
		versions = {},
	}

	---@diagnostic disable-next-line: no-unknown
	for _, v in pairs(decoded.versions) do
		---@type ApiVersion
		local version = {
			num = v.version,
			parsed = semver.parse_version(v.version),
			created = assert(DateTime.parse_iso_8601(decoded.time[v.version])),
		}

		table.insert(package.versions, version)
	end

	table.sort(package.versions, function(a, b)
		return a.created.epoch > b.created.epoch
	end)

	return package
end

---@async
---@param package_name string
---@return string?
api.curl_package = function(package_name)
	local url = REGISTRY .. "/" .. package_name
	local process = nio.process.run({
		cmd = "curl",
		args = { "sL", "--retry", "1", "-A", USERAGENT, url },
	})
	if process then
		local metadata = process.stdout.read()
		process.close()

		if not metadata then
			return
		end

		return metadata
	end
end

---@async
---@param package_names string[]
---@param workDoneToken? lsp.ProgressToken
---@return table<string, PackageMetadata>
api.fetch_packages = function(package_names, workDoneToken)
	local functions = {}
	local pkg_total = #package_names
	local pkg_count = 0
	for _, package_name in ipairs(package_names) do
		table.insert(functions, function()
			local res = api.curl_package(package_name)
			pkg_count = pkg_count + 1
			nio.scheduler()
			if workDoneToken then
				progress.report(workDoneToken, string.format("%s/%s packages", pkg_count, pkg_total))
			end
			return res
		end)
	end
	local outputs = nio.gather(functions)

	local results = {}
	for _, out in ipairs(outputs) do
		local metadata = nio.fn.json_decode(out)

		local pkg = api.parse_metadata(metadata)

		results[pkg.name] = pkg
	end

	return results
end

return api
