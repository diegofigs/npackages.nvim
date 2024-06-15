local api = require("npackages.api")
local async = require("npackages.async")
local core = require("npackages.lsp.core")
local state = require("npackages.lsp.state")
local types = require("npackages.types")
local Span = types.Span
local util = require("npackages.util")

---@class CompletionSource
---@field trigger_characters string[]
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
	},
}

-- lsp CompletionItemKind.Value
local VALUE_KIND = 12

---@param pkg JsonPackage
---@param versions ApiVersion[]
---@return lsp.CompletionList
local function complete_versions(pkg, versions)
	local items = {}

	for i, v in ipairs(versions) do
		---@class lsp.CompletionItem
		local r = {
			label = v.num,
			kind = VALUE_KIND,
			sortText = string.format("%04d", i),
		}
		if pkg.vers and not pkg.vers.quote.e then
			r.insertText = v.num .. pkg.vers.quote.s
		end
		r.cmp = {
			kind_text = "Version",
			kind_hl_group = "CmpItemKindVersion",
		}

		table.insert(items, r)
	end

	return {
		isIncomplete = false,
		items = items,
	}
end

---@param prefix string
---@param col Span
---@param line integer
---@return lsp.CompletionList?
local function complete_packages(prefix, col, line)
	if #prefix < 3 then
		return
	end

	---@type string[]
	local search
	repeat
		search = state.search_cache.searches[prefix]
		if not search then
			---@type ApiPackageSummary[]?, boolean?
			local searches, cancelled
			if api.is_fetching_search(prefix) then
				searches, cancelled = api.await_search(prefix)
			else
				api.cancel_search_jobs()
				searches, cancelled = api.fetch_search(prefix)
			end
			if cancelled then
				return
			end
			if searches then
				state.search_cache.searches[prefix] = {}
				for _, result in ipairs(searches) do
					state.search_cache.results[result.name] = result
					table.insert(state.search_cache.searches[prefix], result.name)
				end
			end
		end
	until search

	local itemDefaults = {
		insertTextFormat = 1,
		editRange = col:range(line),
	}

	local function insertText(name)
		return name
	end
	local results = {}
	for _, r in ipairs(search) do
		local result = state.search_cache.results[r]
		table.insert(results, {
			label = result.name,
			kind = VALUE_KIND,
			detail = result.description,
			textEditText = insertText(result.name),
		})
	end

	return {
		isIncomplete = false,
		items = results,
		itemDefaults = itemDefaults,
	}
end

---@param params lsp.CompletionParams
---@return lsp.CompletionList?
local function complete(params)
	local buf = vim.uri_to_bufnr(params.textDocument.uri)

	local awaited = core.await_throttled_update_if_any(buf)
	if awaited and buf ~= util.current_buf() then
		return
	end

	local line = params.position.line
	local col = params.position.character
	local packages = util.get_lsp_packages(params.textDocument.uri, Span.new(line, line + 1))
	local _, pkg = next(packages)

	-- if state.cfg.completion.npackages.enabled then
	-- 	local working_crates = state.buf_cache[buf].working_crates
	-- 	for _, wcrate in ipairs(working_crates) do
	-- 		if wcrate and wcrate.col:moved(0, 1):contains(col) and line == wcrate.line then
	-- 			local prefix = wcrate.name:sub(1, col - wcrate.col.s)
	-- 			return complete_packages(prefix, wcrate.col, wcrate.line, wcrate.kind)
	-- 		end
	-- 	end
	-- end

	if not pkg then
		return
	end

	if
		pkg.pkg and pkg.pkg.line == line and pkg.pkg.col:moved(0, 1):contains(col)
		or not pkg.pkg
			and pkg.explicit_name
			and pkg.lines.s == line
			and pkg.explicit_name_col:moved(0, 1):contains(col)
	then
		local prefix = pkg.pkg and pkg.pkg.text:sub(1, col - pkg.pkg.col.s)
			or pkg.explicit_name:sub(1, col - pkg.explicit_name_col.s)
		local name_col = pkg.pkg and pkg.pkg.col or pkg.explicit_name_col
		return complete_packages(prefix, name_col, line)
	end

	local api_package = state.api_cache[pkg:package()]

	if not api_package and api.is_fetching_crate(pkg:package()) then
		local _, cancelled = api.await_crate(pkg:package())

		if cancelled or buf ~= util.current_buf() then
			return
		end

		line, col = util.cursor_pos()
		packages = util.get_lsp_packages(params.textDocument.uri, Span.new(line, line + 1))
		_, pkg = next(packages)
		if not pkg then
			return
		end

		api_package = state.api_cache[pkg:package()]
	end

	if not api_package then
		return
	end

	if pkg.vers and pkg.vers.line == line and pkg.vers.col:moved(0, 1):contains(col) then
		return complete_versions(pkg, api_package.versions)
	end
end

---@param params lsp.CompletionParams
---@param callback fun(response: vim.lsp.CompletionResult?)
function M.complete(params, callback)
	vim.schedule(async.wrap(function()
		callback(complete(params))
	end))
end

return M
