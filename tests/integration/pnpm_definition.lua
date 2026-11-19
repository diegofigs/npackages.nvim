vim.opt.runtimepath:prepend(vim.env.NPACKAGES_NIO)
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local root = assert(vim.env.NPACKAGES_FIXTURE) .. "/workspace-definition"

local function write(path, lines)
	path = root .. "/" .. path
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	vim.fn.writefile(lines, path)
end

write("pnpm-workspace.yaml", { "packages:", "  - 'apps/*'", "  - 'packages/*'", "  - '!packages/excluded'" })
write("package.json", { '{"name":"workspace-root","private":true}' })
write("packages/ui/package.json", { '{ "nested": {"name":"wrong"}, "é": 0, "name": "@acme/ui" }' })
write("packages/excluded/package.json", { '{"name":"excluded"}' })
write("apps/web/package.json", {
	"{",
	'  "name": "web",',
	'  "dependencies": {',
	'    "@acme/ui": "workspace:^",',
	'    "alias": "workspace:@acme/ui@*",',
	'    "relative": "workspace:../../packages/ui",',
	'    "excluded": "workspace:*"',
	"  }",
	"}",
})
require("npackages.state").cfg = require("npackages.config.internal").build()
vim.cmd.edit(root .. "/apps/web/package.json")
local buf = vim.api.nvim_get_current_buf()
local id = assert(require("npackages.lsp").start())
local client = assert(vim.lsp.get_client_by_id(id))
local uri = vim.uri_from_bufnr(buf)
local state = require("npackages.lsp.state")
assert(vim.wait(5000, function()
	return state.doc_cache[uri] ~= nil
end))

local function definition(line, character)
	local done, response
	assert(client:request("textDocument/definition", {
		textDocument = { uri = uri },
		position = { line = line, character = character },
	}, function(err, result)
		assert(not err, vim.inspect(err))
		done, response = true, result
	end, buf))
	assert(vim.wait(7000, function()
		return done
	end), "definition timed out")
	return response
end

local target = vim.uri_from_fname(root .. "/packages/ui/package.json")
for _, pos in ipairs({ { 3, 6 }, { 3, 22 }, { 4, 6 }, { 5, 6 } }) do
	local result = definition(pos[1], pos[2])
	assert(result[1].targetUri == target, vim.inspect(result))
	assert(result[1].targetSelectionRange.start.character == 38, vim.inspect(result))
end
assert(#definition(6, 6) == 0)

local system = vim.system
vim.system = function()
	error("pnpm unavailable")
end
write("apps/web/node_modules/@acme/ui/package.json", { '{"name":"@acme/ui"}' })
assert(definition(3, 22)[1].targetUri == vim.uri_from_fname(root .. "/apps/web/node_modules/@acme/ui/package.json"))
vim.system = system

write("packages/duplicate/package.json", { '{"name":"@acme/ui"}' })
assert(#definition(3, 6) == 0)

local other = root .. "/other"
write("other/pnpm-workspace.yaml", { "packages:", "  - 'packages/*'" })
write("other/package.json", { '{"name":"other","private":true}' })
write("other/packages/ui/package.json", { '{"name":"@acme/ui"}' })
local resolved
require("npackages.lsp.pnpm").resolve(vim.uri_from_fname(other .. "/package.json"), "@acme/ui", "*", function(path)
	resolved = path or false
end)
assert(vim.wait(7000, function()
	return resolved ~= nil
end))
assert(resolved == other .. "/packages/ui/package.json", vim.inspect(resolved))

vim.system = function(_, _, callback)
	vim.schedule(function()
		local doc = state.documents[uri]
		doc.version = doc.version + 1
		callback({ code = 0, stdout = vim.json.encode({ { name = "@acme/ui", path = root .. "/packages/ui" } }) })
	end)
	return {}
end
assert(#definition(3, 6) == 0)
vim.system = system
