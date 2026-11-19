local state = require("npackages.lsp.state")

local pnpm = require("npackages.lsp.pnpm")

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
		return nil
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
local function installed(params, pkg)
	local doc = state.documents[params.textDocument.uri]
	if doc == nil then
		return {}
	end

	local lines = split(doc.text, "\n")
	if not lines then
		return {}
	end

	local word = get_word_at_position(lines, params.position)
	if not word and not pkg then
		return {}
	end

	local pkg_in_position = pkg or get_package_in_position(doc.uri, params.position)
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

local function position(text, offset, encoding)
	local prefix = text:sub(1, offset)
	local line = vim.split(prefix, "\n", { plain = true })
	return { line = #line - 1, character = vim.str_utfindex(line[#line], encoding) }
end

local function name_range(text, encoding)
	local depth, cursor = 0, 1
	-- Skip JSON strings as units so nested keys and braces in values cannot
	-- be mistaken for the manifest's top-level name.
	while cursor <= #text do
		local char = text:sub(cursor, cursor)
		if char == '"' then
			local start = cursor
			cursor = cursor + 1
			while cursor <= #text and text:sub(cursor, cursor) ~= '"' do
				cursor = cursor + (text:sub(cursor, cursor) == "\\" and 2 or 1)
			end
			if depth == 1 and text:match("^%s*:", cursor + 1) then
				local ok, key = pcall(vim.json.decode, text:sub(start, cursor))
				if ok and key == "name" then
					return { start = position(text, start - 1, encoding), ["end"] = position(text, cursor, encoding) }
				end
			end
		elseif char == "{" or char == "[" then
			depth = depth + 1
		elseif char == "}" or char == "]" then
			depth = depth - 1
		end
		cursor = cursor + 1
	end
	local start = { line = 0, character = 0 }
	return { start = start, ["end"] = start }
end

function M.get(params, callback)
	local uri = params.textDocument.uri
	local doc = state.documents[uri]
	local pkg = get_package_in_position(uri, params.position)
	local spec = pkg and pkg.vers and pkg.vers.text:match("^workspace:(.+)$")
	if not doc or not spec then
		return callback(nil, installed(params))
	end

	local id = state.session.client_id
	local client = id and vim.lsp.get_client_by_id(id)
	local encoding = client and client.offset_encoding or "utf-16"
	local line = vim.split(doc.text, "\n", { plain = true })[params.position.line + 1] or ""
	local column = vim.str_byteindex(line, encoding, params.position.character, false)
	if column < pkg.range.start.character or column >= pkg.vers.quote["end"].character then
		return callback(nil, {})
	end

	local text, version = doc.text, doc.version
	pnpm.resolve(uri, pkg.explicit_name, spec, function(path, authoritative)
		if state.documents[uri] ~= doc or doc.text ~= text or doc.version ~= version then
			return callback(nil, {})
		end
		if path then
			local ok, lines = pcall(vim.fn.readfile, path)
			if ok then
				local range = name_range(table.concat(lines, "\n"), encoding)
				return callback(nil, { {
					targetUri = vim.uri_from_fname(path),
					targetRange = range,
					targetSelectionRange = range,
				} })
			end
		end
		callback(nil, authoritative and not path and {} or installed(params, pkg))
	end)
end

return M
