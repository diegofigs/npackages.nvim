local nio = require("nio")
local time = require("npackages.lib.time")
local semver = require("npackages.lib.semver")
local DateTime = time.DateTime

local api = {}

local REGISTRY = "https://registry.npmjs.org"
local USERAGENT = "npackages.nvim (https://github.com/diegofigs/npackages.nvim)"

---Maps a metadata table to PackageMetadata
---@param decoded table
---@param yield_callback? fun() Optional cooperative checkpoint for async callers.
---@return PackageMetadata
api.parse_metadata = function(decoded, yield_callback)
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

	local processed = 0
	for version, vdata in pairs(decoded.versions) do
		processed = processed + 1
		if yield_callback and processed % 100 == 0 then
			yield_callback()
		end
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

-- Completion and cleanup run independently of the caller's nio task. A buffer
-- change may cancel indexing while curl is still writing its temporary file.
local download = nio.wrap(function(args, path, callback)
	vim.system(args, { timeout = 45000 }, function(result)
		nio.run(function()
			local fd
			local ok, value = pcall(function()
				assert(result.code == 0, "Registry fetch failed (curl exit " .. tostring(result.code) .. ")")
				local err
				err, fd = nio.uv.fs_open(path, "r", 384)
				assert(fd, err)
				local stat_err, stat = nio.uv.fs_fstat(fd)
				assert(stat, stat_err)
				local read_err, data = nio.uv.fs_read(fd, stat.size, 0)
				assert(data, read_err)
				return data
			end)
			if fd then
				nio.uv.fs_close(fd)
			end
			nio.uv.fs_unlink(path)
			callback(ok, value)
		end, function(ok, err)
			if not ok then
				vim.uv.fs_unlink(path, function()
					callback(false, err)
				end)
			end
		end)
	end)
end, 3)

---@async
---@param package_name string
---@return string
api.curl_package = function(package_name)
	local path = nio.fn.tempname()
	-- Curl rewinds file output before retries; stdout cannot be rewound.
	local ok, result = download({
		"curl",
		"-sL",
		"--retry",
		"1",
		"-A",
		USERAGENT,
		"--compressed",
		"--fail",
		"--connect-timeout",
		"5",
		"--max-time",
		"20",
		"--retry-max-time",
		"25",
		"--output",
		path,
		REGISTRY .. "/" .. package_name,
	}, path)
	if not ok then
		error(result)
	end
	return result
end

return api
