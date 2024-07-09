local state = require("npackages.lsp.state")

local M = {}

local function split(s, delimiter)
	delimiter = delimiter or " "
	local result = {}
	for word in string.gmatch(s, "(.-)" .. delimiter) do
		table.insert(result, word)
	end
	if #result == 0 then
		return nil
	end
	return result
end

---@param uri lsp.DocumentUri
---@param pos lsp.Position
---@return JsonPackage|nil
local function get_package_in_position(uri, pos)
	local cache = state.doc_cache[uri]
	local packages = cache and cache.packages
	if not packages then
		return {}
	end

	local pkg = nil
	for _, p in pairs(packages) do
		if pos.line == p.range.start.line then
			pkg = p
		end
	end

	return pkg
end

local function resolve_package_json_path(package_name, current_uri)
	local current_folder = vim.uri_to_fname(current_uri):match("(.*[/\\])")
	local package_json_path = current_folder .. "node_modules/" .. package_name .. "/package.json"
	local file = io.open(package_json_path, "r")
	if file then
		file:close()
		return package_json_path
	else
		return nil
	end
end

local function get_word_at_position(lines, position)
	local line = lines[position.line + 1]
	if not line then
		return nil
	end

	local start_col, end_col = line:find("[%w_%-]+", position.character + 1)
	if start_col and end_col then
		return line:sub(start_col, end_col)
	end

	return nil
end

---@param params lsp.DefinitionParams
---@return lsp.LocationLink[]
function M.get(params)
	local doc = state.documents[params.textDocument.uri]
	if doc == nil then
		return {}
	end

	local lines = split(doc.text, "\n")
	if not lines then
		return {}
	end

	local word = get_word_at_position(lines, params.position)
	if not word then
		return {}
	end

	local pkg_in_position = get_package_in_position(doc.uri, params.position)
	if not pkg_in_position then
		return {}
	end

	local package_json_path = resolve_package_json_path(pkg_in_position.explicit_name, params.textDocument.uri)
	if not package_json_path then
		return {}
	end

	local location_links = {}
	local target_range = {
		start = { line = 0, character = 0 },
		["end"] = { line = 0, character = 0 },
	}
	local target_selection_range = target_range
	---@type lsp.LocationLink
	local location_link = {
		targetUri = vim.uri_from_fname(package_json_path),
		targetRange = target_range,
		targetSelectionRange = target_selection_range,
		originSelectionRange = pkg_in_position.range,
	}
	table.insert(location_links, location_link)

	return location_links
end

return M
