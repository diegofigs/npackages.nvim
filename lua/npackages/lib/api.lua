local semver = require("npackages.lib.semver")
local state = require("npackages.state")
local time = require("npackages.lib.time")
local json = require("npackages.lib.json")
local DateTime = time.DateTime

local M = {
	---@type table<string,PackageJob>
	crate_jobs = {},
	---@type table<string,DepsJob>
	deps_jobs = {},
	---@type table<string,SearchJob>
	search_jobs = {},
	---@type QueuedJob[]
	queued_jobs = {},
	---@type QueuedSearchJob[]
	search_queue = {},
	---@type integer
	num_requests = 0,
}

---@class Job
---@field handle uv_process_t|nil
---@field was_cancelled boolean|nil

---@class PackageJob
---@field job Job
---@field callbacks fun(crate: PackageMetadata|nil, cancelled: boolean)[]

---@class DepsJob
---@field job Job
---@field callbacks fun(deps: ApiDependency[]|nil, cancelled: boolean)[]

---@class SearchJob
---@field job Job
---@field callbacks fun(search: ApiPackageSummary[]?, cancelled: boolean)[]

---@class QueuedJob
---@field kind JobKind
---@field name string
---@field crate_callbacks fun(crate: PackageMetadata|nil, cancelled: boolean)[]
---@field version string
---@field deps_callbacks fun(deps: ApiDependency[]|nil, cancelled: boolean)[]
---@class QueuedSearchJob
---@field name string
---@field callbacks fun(deps: ApiPackageSummary[]?, cancelled: boolean)[]

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

---@enum JobKind
local JobKind = {
	CRATE = 1,
	DEPS = 2,
}

---@enum ApiDependencyKind
local ApiDependencyKind = {
	NORMAL = 1,
	DEV = 2,
	BUILD = 3,
}

local SIGTERM = 15
local ENDPOINT = "https://registry.npmjs.org"
local USERAGENT = vim.fn.shellescape("npackages.nvim (https://github.com/diegofigs/npackages.nvim)")

local DEPENDENCY_KIND_MAP = {
	["normal"] = ApiDependencyKind.NORMAL,
	["dev"] = ApiDependencyKind.DEV,
	-- ["build"] = ApiDependencyKind.BUILD,
}

---@param url string
---@param on_exit fun(data: string|nil, cancelled: boolean)
---@return Job|nil
local function start_job(url, on_exit)
	---@type Job
	local job = {}
	local stdout = vim.uv.new_pipe()

	---@type string|nil
	local stdout_str = nil

	local opts = {
		args = { unpack(state.cfg.curl_args), "-A", USERAGENT, url },
		stdio = { nil, stdout, nil },
	}
	local handle
	---@param code integer
	---@param _signal integer
	---@type uv_process_t, integer
	handle = vim.uv.spawn("curl", opts, function(code, _signal)
		handle:close()

		local success = code == 0

		local check = vim.uv.new_check()
		if check ~= nil and stdout ~= nil then
			check:start(function()
				if not stdout:is_closing() then
					return
				end
				check:stop()

				vim.schedule(function()
					local data = success and stdout_str or nil
					on_exit(data, job.was_cancelled)
				end)
			end)
		end
	end)

	if not handle then
		return nil
	end

	local accum = {}
	if stdout ~= nil then
		stdout:read_start(function(err, data)
			if err then
				stdout:read_stop()
				stdout:close()
				return
			end

			if data ~= nil then
				table.insert(accum, data)
			else
				stdout_str = table.concat(accum)
				stdout:read_stop()
				stdout:close()
			end
		end)
	end

	job.handle = handle
	return job
end

---@param job Job
local function cancel_job(job)
	if job.handle then
		job.handle:kill(SIGTERM)
	end
end

---@param name string
---@param callbacks fun(crate: PackageMetadata|nil, cancelled: boolean)[]
local function enqueue_crate_job(name, callbacks)
	for _, j in ipairs(M.queued_jobs) do
		if j.kind == JobKind.CRATE and j.name == name then
			vim.list_extend(j.crate_callbacks, callbacks)
			return
		end
	end

	table.insert(M.queued_jobs, {
		kind = JobKind.CRATE,
		name = name,
		crate_callbacks = callbacks,
	})
end

---@param name string
---@param version string
---@param callbacks fun(deps: ApiDependency[]|nil, cancelled: boolean)[]
local function enqueue_deps_job(name, version, callbacks)
	for _, j in ipairs(M.queued_jobs) do
		if j.kind == JobKind.DEPS and j.name == name and j.version == version then
			vim.list_extend(j.deps_callbacks, callbacks)
			return
		end
	end

	table.insert(M.queued_jobs, {
		kind = JobKind.DEPS,
		name = name,
		version = version,
		deps_callbacks = callbacks,
	})
end

---@param name string
---@param callbacks fun(search: ApiPackageSummary[]?, cancelled: boolean)[]
local function enqueue_search_job(name, callbacks)
	for _, j in ipairs(M.search_queue) do
		if j.name == name then
			vim.list_extend(j.callbacks, callbacks)
			return
		end
	end

	table.insert(M.search_queue, {
		name = name,
		callbacks = callbacks,
	})
end

---@param json_str string
---@return ApiPackageSummary[]?
function M.parse_search(json_str)
	local decoded = json.decode(json_str)
	if not (decoded and decoded.objects) then
		return
	end

	---@type ApiPackageSummary[]
	local search = {}
	---@diagnostic disable-next-line: no-unknown
	for _, c in ipairs(decoded.objects) do
		---@type ApiPackageSummary
		local result = {
			name = c.package.name,
			description = c.package.description,
			newest_version = c.package.version,
		}
		table.insert(search, result)
	end

	return search
end

---@param name string
---@param callbacks fun(search: ApiPackageSummary[]?, cancelled: boolean)[]
local function fetch_search(name, callbacks)
	local existing = M.search_jobs[name]
	if existing then
		vim.list_extend(existing.callbacks, callbacks)
		return
	end

	if M.num_requests >= state.cfg.max_parallel_requests then
		enqueue_search_job(name, callbacks)
		return
	end

	local url =
		string.format("%s/-/v1/search?text=%s&size=%s", ENDPOINT, name, state.cfg.completion.npackages.max_results)

	---@param json_str string?
	---@param cancelled boolean
	local function on_exit(json_str, cancelled)
		---@type ApiPackageSummary[]?
		local search
		if not cancelled and json_str then
			local ok, s = pcall(M.parse_search, json_str)
			if ok then
				search = s
			end
		end
		for _, c in ipairs(callbacks) do
			c(search, cancelled)
		end

		M.search_jobs[name] = nil
		M.num_requests = M.num_requests - 1

		M.run_queued_jobs()
	end

	local job = start_job(url, on_exit)
	if job then
		M.num_requests = M.num_requests + 1
		M.search_jobs[name] = {
			job = job,
			callbacks = callbacks,
		}
	else
		for _, c in ipairs(callbacks) do
			c(nil, false)
		end
	end
end

---@param name string
---@return ApiPackageSummary[]?, boolean
function M.fetch_search(name)
	---@param resolve fun(search: ApiPackageSummary[]?, cancelled: boolean)
	return coroutine.yield(function(resolve)
		fetch_search(name, { resolve })
	end)
end

---@param json_str string
---@return PackageMetadata|nil
function M.parse_package(json_str)
	local decoded = json.decode(json_str)
	if not decoded then
		return nil
	end

	---@type table<string,any>
	local p = decoded

	---@type PackageMetadata
	local crate = {
		name = p.name,
		description = assert(p.description),
		created = assert(DateTime.parse_iso_8601(p.time.created)),
		updated = assert(DateTime.parse_iso_8601(p.time.modified)),
		-- downloads = assert(p.downloads),
		homepage = p.homepage,
		-- documentation = p.documentation,
		repository = p.repository and p.repository.url and p.repository.url:match("^.*%+(.*)%..*$"),
		categories = {},
		keywords = p.keywords or {},
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

		table.insert(crate.versions, version)
	end

	table.sort(crate.versions, function(a, b)
		return a.created.epoch > b.created.epoch
	end)

	return crate
end

---@param name string
---@param callbacks fun(crate: PackageMetadata|nil, cancelled: boolean)[]
local function fetch_crate(name, callbacks)
	local existing = M.crate_jobs[name]
	if existing then
		vim.list_extend(existing.callbacks, callbacks)
		return
	end

	if M.num_requests >= state.cfg.max_parallel_requests then
		enqueue_crate_job(name, callbacks)
		return
	end

	local url = string.format("%s/%s", ENDPOINT, name)

	---@param json_str string|nil
	---@param cancelled boolean
	local function on_exit(json_str, cancelled)
		---@type PackageMetadata|nil
		local crate
		if not cancelled and json_str then
			local ok, c = pcall(M.parse_package, json_str)
			if ok then
				crate = c
			end
		end
		for _, c in ipairs(callbacks) do
			c(crate, cancelled)
		end

		M.crate_jobs[name] = nil
		M.num_requests = M.num_requests - 1

		M.run_queued_jobs()
	end

	local job = start_job(url, on_exit)
	if job then
		M.num_requests = M.num_requests + 1
		M.crate_jobs[name] = {
			job = job,
			callbacks = callbacks,
		}
	else
		for _, c in ipairs(callbacks) do
			c(nil, false)
		end
	end
end

---@param name string
---@return PackageMetadata|nil, boolean
function M.fetch_crate(name)
	---@param resolve fun(crate: PackageMetadata|nil, cancelled: boolean)
	return coroutine.yield(function(resolve)
		fetch_crate(name, { resolve })
	end)
end

---@param json_str string
---@return ApiDependency[]|nil
function M.parse_deps(json_str)
	local decoded = json.decode(json_str)
	if not (decoded and decoded.dependencies) then
		return
	end

	---@type ApiDependency[]
	local dependencies = {}
	---@diagnostic disable-next-line: no-unknown
	for name, vers in pairs(decoded.dependencies) do
		---@type ApiDependency
		local dependency = {
			name = name,
			opt = false,
			kind = DEPENDENCY_KIND_MAP["normal"],
			vers = {
				text = vers,
				reqs = semver.parse_requirements(vers),
			},
		}
		table.insert(dependencies, dependency)
	end

	return dependencies
end

---@param name string
---@param version string
---@param callbacks fun(deps: ApiDependency[]|nil, cancelled: boolean)[]
local function fetch_deps(name, version, callbacks)
	local jobname = name .. ":" .. version
	local existing = M.deps_jobs[jobname]
	if existing then
		vim.list_extend(existing.callbacks, callbacks)
		return
	end

	if M.num_requests >= state.cfg.max_parallel_requests then
		enqueue_deps_job(name, version, callbacks)
		return
	end

	local url = string.format("%s/%s/%s", ENDPOINT, name, version)

	---@param json_str string
	---@param cancelled boolean
	local function on_exit(json_str, cancelled)
		---@type ApiDependency[]|nil
		local deps
		if not cancelled and json_str then
			local ok, d = pcall(M.parse_deps, json_str)
			if ok then
				deps = d
			end
		end
		for _, c in ipairs(callbacks) do
			c(deps, cancelled)
		end

		M.num_requests = M.num_requests - 1
		M.deps_jobs[jobname] = nil

		M.run_queued_jobs()
	end

	local job = start_job(url, on_exit)
	if job then
		M.num_requests = M.num_requests + 1
		M.deps_jobs[jobname] = {
			job = job,
			callbacks = callbacks,
		}
	else
		for _, c in ipairs(callbacks) do
			c(nil, false)
		end
	end
end

---@param name string
---@param version string
---@return ApiDependency[]|nil, boolean
function M.fetch_deps(name, version)
	---@param resolve fun(deps: ApiDependency[]|nil, cancelled: boolean)
	return coroutine.yield(function(resolve)
		fetch_deps(name, version, { resolve })
	end)
end

---@param name string
---@return boolean
function M.is_fetching_crate(name)
	return M.crate_jobs[name] ~= nil
end

---@param name string
---@param version string
---@return boolean
function M.is_fetching_deps(name, version)
	return M.deps_jobs[name .. ":" .. version] ~= nil
end

---@param name string
---@return boolean
function M.is_fetching_search(name)
	return M.search_jobs[name] ~= nil
end

---@param name string
---@param callback fun(crate: PackageMetadata|nil, cancelled: boolean)
local function add_crate_callback(name, callback)
	table.insert(M.crate_jobs[name].callbacks, callback)
end

---@param name string
---@return PackageMetadata|nil, boolean
function M.await_crate(name)
	---@param resolve fun(crate: PackageMetadata|nil, cancelled: boolean)
	return coroutine.yield(function(resolve)
		add_crate_callback(name, resolve)
	end)
end

---@param name string
---@param version string
---@param callback fun(deps: ApiDependency[]|nil, cancelled: boolean)
local function add_deps_callback(name, version, callback)
	table.insert(M.deps_jobs[name .. ":" .. version].callbacks, callback)
end

---@param name string
---@param version string
---@return ApiDependency[]|nil, boolean
function M.await_deps(name, version)
	---@param resolve fun(crate: ApiDependency[]|nil, cancelled: boolean)
	return coroutine.yield(function(resolve)
		add_deps_callback(name, version, resolve)
	end)
end

---@param name string
---@param callback fun(deps: ApiPackageSummary[]?, cancelled: boolean)
local function add_search_callback(name, callback)
	table.insert(M.search_jobs[name].callbacks, callback)
end

---@param name string
---@return ApiPackageSummary[]?, boolean
function M.await_search(name)
	---@param resolve fun(crate: ApiPackageSummary[]?, cancelled: boolean)
	return coroutine.yield(function(resolve)
		add_search_callback(name, resolve)
	end)
end

function M.run_queued_jobs()
	-- Prioritise crate searches
	if #M.search_queue > 0 then
		local job = table.remove(M.search_queue, 1)
		fetch_search(job.name, job.search_callbacks)
		return
	end

	if #M.queued_jobs == 0 then
		return
	end

	local job = table.remove(M.queued_jobs, 1)
	if job.kind == JobKind.CRATE then
		fetch_crate(job.name, job.crate_callbacks)
	elseif job.kind == JobKind.DEPS then
		fetch_deps(job.name, job.version, job.deps_callbacks)
	end
end

function M.cancel_jobs()
	for _, r in pairs(M.crate_jobs) do
		cancel_job(r.job)
	end
	for _, r in pairs(M.deps_jobs) do
		cancel_job(r.job)
	end

	M.crate_jobs = {}
	M.deps_jobs = {}
	M.search_jobs = {}
end

function M.cancel_search_jobs()
	M.search_jobs = {}
end

return M
