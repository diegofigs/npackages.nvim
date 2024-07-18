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

return api
