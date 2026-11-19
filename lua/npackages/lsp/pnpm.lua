local M = {}

-- A successful listing with no unique match is authoritative. A failed listing
-- lets the definition handler try the installed package.
function M.resolve(uri, name, spec, callback)
	local source = vim.fs.dirname(vim.uri_to_fname(uri))
	local root = vim.fs.root(source, "pnpm-workspace.yaml")
	if not root or vim.fn.executable("pnpm") ~= 1 then
		return callback(nil, false)
	end

	local relative = spec:match("^%.%./") or spec:match("^%./")
	local directory = relative and vim.fs.normalize(vim.fs.joinpath(source, spec))
	local alias = spec:match("^(.+)@[^@]+$")
	local target = alias or name
	local started = pcall(vim.system, { "pnpm", "list", "--recursive", "--depth", "-1", "--json" }, {
		cwd = root,
		timeout = 5000,
		text = true,
	}, vim.schedule_wrap(function(result)
		local ok, members = pcall(vim.json.decode, result.stdout or "")
		if result.code ~= 0 or not ok or not vim.islist(members) then
			return callback(nil, false)
		end
		local found
		for _, member in ipairs(members) do
			if type(member) ~= "table" or type(member.path) ~= "string" then
				return callback(nil, false)
			end
			local path = vim.fs.normalize(member.path)
			if (directory and path == directory) or (not directory and member.name == target) then
				if found and found ~= path then
					return callback(nil, true)
				end
				found = path
			end
		end
		callback(found and vim.fs.joinpath(found, "package.json"), true)
	end))
	if not started then
		callback(nil, false)
	end
end

return M
