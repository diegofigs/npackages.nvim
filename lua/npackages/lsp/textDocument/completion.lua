local state = require("npackages.lsp.state")
local nio = require("nio")

local M = {
	trigger_characters = {
		'"',
		"'",
		".",
		"<",
		">",
		"=",
		"^",
		"~",
		"1",
		"2",
		"3",
		"4",
		"5",
		"6",
		"7",
		"8",
		"9",
		"0",
		"a",
		"b",
		"c",
		"d",
		"e",
		"f",
		"g",
		"h",
		"i",
		"j",
		"k",
		"l",
		"m",
		"n",
		"o",
		"p",
		"q",
		"r",
		"s",
		"t",
		"u",
		"v",
		"w",
		"x",
		"y",
		"z",
		"-",
		"_",
	},
}

-- TODO: expose completion opts as lsp settings or remove them
local opts = {
	ignore = {},
	only_semantic_versions = true,
	only_latest_version = false,
}

local function sort_versions(versions)
	local version_list = {}

	-- Iterate versions from the end to show the latest versions first
	for index = #versions, 1, -1 do
		local version = versions[index]
		local is_unstable = string.match(version, "-")

		-- TODO: Option to skip unstable version e.g next@11.1.0-canary
		if not is_unstable then
			table.insert(version_list, version)
			-- else
			-- 	table.insert(version_list, version)
		end
	end

	return version_list
end

---@type lsp.CompletionItemKind
local FIELD_KIND = 5
---@type lsp.CompletionItemKind
local VALUE_KIND = 12

---@param params lsp.CompletionParams
---@param callback fun(err, res)
function M.complete(params, callback)
	local doc = state.documents[params.textDocument.uri]
	-- figure out if we are completing the package name or version
	local line = params.position.line
	local cur_line = vim.api.nvim_buf_get_lines(vim.uri_to_bufnr(doc.uri), line, line + 1, false)[1]

	local cur_col = params.position.character

	local name = string.match(cur_line, '%s*"([^"]*)"?')

	-- Find the positions of the quotes
	local quote_positions = {}
	for i = 1, #cur_line do
		if cur_line:sub(i, i) == '"' then
			table.insert(quote_positions, i)
		end
	end

	-- Determine if we are in the version part
	local find_version = false
	if #quote_positions >= 3 then
		local idx_after_third_quote = quote_positions[3]
		find_version = cur_col >= idx_after_third_quote
	end

	if name == nil then
		return
	end

	local cb = function(success, res)
		callback(nil, res)
	end
	if find_version then
		if opts.only_latest_version then
			nio.run(function()
				local process = nio.process.run({
					cmd = "npm",
					args = { "info", name, "version" },
				})
				if process then
					local output = process.stdout.read()
					process.close()

					if output then
						local raw = nio.fn.split(output, "\n")

						local version = raw[1]
						if version then
							local cmp = {
								kind_text = "Version",
								kind_hl_group = "CmpItemKindVersion",
							}
							local versions = {
								{ label = version, cmp = cmp },
								{ label = "^" .. version, cmp = cmp },
								{ label = "~" .. version, cmp = cmp },
							}
							return versions
						end
					end
				end
			end, cb)
		else
			nio.run(function()
				local process = nio.process.run({
					cmd = "npm",
					args = { "info", name, "versions", "--json" },
				})
				if process then
					local output = process.stdout.read()
					process.close()

					if output then
						local raw = nio.fn.split(output, "\n")
						table.remove(raw, 1)
						table.remove(raw, #raw)

						local items = {}
						local versions = {}
						for _, npm_item in ipairs(raw) do
							local version = string.match(npm_item, '%s*"(.*)",?')

							if opts.only_semantic_versions and not string.match(version, "^%d+%.%d+%.%d+$") then
								goto continue
							else
								for _, ignoreString in ipairs(opts.ignore) do
									if string.match(version, ignoreString) then
										goto continue
									end
								end
							end

							table.insert(versions, version)
							::continue::
						end

						local sorted_versions = sort_versions(versions)

						for i, v in ipairs(sorted_versions) do
							---@type lsp.CompletionItem
							local r = {
								label = v,
								kind = VALUE_KIND,
								sortText = string.format("%04d", i),
								cmp = {
									kind_text = "Version",
									kind_hl_group = "CmpItemKindVersion",
								},
							}
							table.insert(items, r)
						end
						-- unfortunately, nvim-cmp uses its own sorting algorith which doesn't work for semantic versions
						-- but at least we can bring the original set in order
						-- table.sort(items, function(a, b)
						-- 	local a_major, a_minor, a_patch = string.match(a.label, "(%d+)%.(%d+)%.(%d+)")
						-- 	local b_major, b_minor, b_patch = string.match(b.label, "(%d+)%.(%d+)%.(%d+)")
						-- 	if a_major ~= b_major then
						-- 		return tonumber(a_major) > tonumber(b_major)
						-- 	end
						-- 	if a_minor ~= b_minor then
						-- 		return tonumber(a_minor) > tonumber(b_minor)
						-- 	end
						-- 	if a_patch ~= b_patch then
						-- 		return tonumber(a_patch) > tonumber(b_patch)
						-- 	end
						-- end)

						return items
					end
				end
			end, cb)
		end
	else
		nio.run(function()
			local process = nio.process.run({
				cmd = "npm",
				args = { "search", "--no-description", "--parseable", name },
			})
			if process then
				local output = process.stdout.read()
				process.close()

				if output then
					local items = {}
					for i, npm_item in ipairs(nio.fn.split(output, "\n")) do
						local pkg_descriptor, _, _ = string.match(npm_item, "(.*)\t(.*)\t(.*)\t")
						local pkg_name = pkg_descriptor:gsub("%s.*", "")
						-- local label = pkg_descriptor .. " " .. version
						---@class lsp.CompletionItem
						local r = {
							label = pkg_name,
							labelDetails = pkg_descriptor,
							kind = FIELD_KIND,
							sortText = string.format("%04d", i),
						}
						r.cmp = {
							kind_text = "Package",
							kind_hl_group = "CmpItemKindPackage",
						}

						table.insert(items, r)
					end

					return items
				end
			end
		end, cb)
	end
end

return M
