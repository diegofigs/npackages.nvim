local nio = require("nio")
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
	local metadata = decoded

	---@type PackageMetadata
	local package = {
		name = metadata.name,
		description = assert(metadata.description),
		created = assert(DateTime.parse_iso_8601(metadata.time.created)),
		updated = assert(DateTime.parse_iso_8601(metadata.time.modified)),
		homepage = metadata.homepage,
		repository = metadata.repository and metadata.repository.url and metadata.repository.url:match(
			"^.*%+(.*)%..*$"
		),
		categories = {},
		keywords = metadata.keywords or {},
		versions = {},
	}

	for version, vdata in pairs(decoded.versions) do
		local version_info = {
			num = vdata.version,
			parsed = semver.parse_version(vdata.version),
			created = assert(DateTime.parse_iso_8601(decoded.time[version])),
			dependencies = {},
			devDependencies = {},
		}

		if vdata.dependencies then
			for dep, ver in pairs(vdata.dependencies) do
				table.insert(version_info.dependencies, { name = dep, version = ver })
			end
		end

		if vdata.devDependencies then
			for dep, ver in pairs(vdata.devDependencies) do
				table.insert(version_info.devDependencies, { name = dep, version = ver })
			end
		end

		table.insert(package.versions, version_info)
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

return api
