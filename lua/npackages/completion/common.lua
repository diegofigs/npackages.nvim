local api = require("npackages.api")
local async = require("npackages.async")
local core = require("npackages.core")
local state = require("npackages.state")
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

---@class CompletionList
---@field isIncomplete boolean
---@field items CompletionItem[]

---@class CompletionItem
---@field label string
---@field kind integer|nil -- CompletionItemKind|nil
---@field detail string|nil
---@field documentation string|nil
---@field deprecated boolean|nil
---@field sortText string|nil
---@field insertText string|nil
---@field cmp CmpCompletionExtension|nil

---@class CmpCompletionExtension
---@field kind_text string
---@field kind_hl_group string

-- lsp CompletionItemKind.Value
local VALUE_KIND = 12

---@param crate JsonPackage
---@param versions ApiVersion[]
---@return CompletionList
local function complete_versions(crate, versions)
	local items = {}

	for i, v in ipairs(versions) do
		---@type CompletionItem
		local r = {
			label = v.num,
			kind = VALUE_KIND,
			sortText = string.format("%04d", i),
		}
		if state.cfg.completion.insert_closing_quote then
			if crate.vers and not crate.vers.quote.e then
				r.insertText = v.num .. crate.vers.quote.s
			end
		end
		-- if v.yanked then
		-- 	r.deprecated = true
		-- 	r.documentation = state.cfg.completion.text.yanked
		-- elseif v.parsed.pre then
		-- 	r.documentation = state.cfg.completion.text.prerelease
		-- end
		if state.cfg.completion.cmp.use_custom_kind then
			r.cmp = {
				kind_text = state.cfg.completion.cmp.kind_text.version,
				kind_hl_group = state.cfg.completion.cmp.kind_highlight.version,
			}
		end

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
---@param kind WorkingCrateKind?
---@return CompletionList?
local function complete_packages(prefix, col, line, kind)
	if #prefix < state.cfg.completion.npackages.min_chars then
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
		insertTextFormat = kind and 2 or 1,
		editRange = kind and col:range(line),
	}

	local function insertText(name)
		return name
	end
	if kind and kind == types.WorkingCrateKind.INLINE then
		insertText = function(name, version)
			return ('%s = "${1:%s}"'):format(name, version)
		end
	elseif kind and kind == types.WorkingCrateKind.TABLE then
		itemDefaults.editRange = col:moved(0, 1):range(line)
		insertText = function(name, version)
			return ('%s]\nversion = "${1:%s}"'):format(name, version)
		end
	else
	end

	local results = {}
	for _, r in ipairs(search) do
		local result = state.search_cache.results[r]
		table.insert(results, {
			label = result.name,
			kind = VALUE_KIND,
			detail = result.description,
			textEditText = insertText(result.name, result.newest_version),
		})
	end

	return {
		isIncomplete = false,
		items = results,
		itemDefaults = itemDefaults,
	}
end

---@return CompletionList|nil
local function complete()
	local buf = util.current_buf()

	local awaited = core.await_throttled_update_if_any(buf)
	if awaited and buf ~= util.current_buf() then
		return
	end

	local line, col = util.cursor_pos()
	local packages = util.get_line_packages(buf, Span.new(line, line + 1))
	local _, crate = next(packages)

	if state.cfg.completion.npackages.enabled then
		local working_crates = state.buf_cache[buf].working_crates
		for _, wcrate in ipairs(working_crates) do
			if wcrate and wcrate.col:moved(0, 1):contains(col) and line == wcrate.line then
				local prefix = wcrate.name:sub(1, col - wcrate.col.s)
				return complete_packages(prefix, wcrate.col, wcrate.line, wcrate.kind)
			end
		end
	end

	if not crate then
		return
	end

	if state.cfg.completion.npackages.enabled then
		if
			crate.pkg and crate.pkg.line == line and crate.pkg.col:moved(0, 1):contains(col)
			or not crate.pkg
				and crate.explicit_name
				and crate.lines.s == line
				and crate.explicit_name_col:moved(0, 1):contains(col)
		then
			local prefix = crate.pkg and crate.pkg.text:sub(1, col - crate.pkg.col.s)
				or crate.explicit_name:sub(1, col - crate.explicit_name_col.s)
			local name_col = crate.pkg and crate.pkg.col or crate.explicit_name_col
			return complete_packages(prefix, name_col, line)
		end
	end

	local api_package = state.api_cache[crate:package()]

	if not api_package and api.is_fetching_crate(crate:package()) then
		local _api_package, cancelled = api.await_crate(crate:package())

		if cancelled or buf ~= util.current_buf() then
			return
		end

		line, col = util.cursor_pos()
		packages = util.get_line_packages(buf, Span.new(line, line + 1))
		_, crate = next(packages)
		if not crate then
			return
		end

		api_package = state.api_cache[crate:package()]
	end

	if not api_package then
		return
	end

	if crate.vers and crate.vers.line == line and crate.vers.col:moved(0, 1):contains(col) then
		return complete_versions(crate, api_package.versions)
		-- elseif crate.feat and crate.feat.line == line and crate.feat.col:moved(0, 1):contains(col) then
		-- 	for _, f in ipairs(crate.feat.items) do
		-- 		if f.col:moved(0, 1):contains(col - crate.feat.col.s) then
		-- 			return complete_features(crate, f, api_crate.versions)
		-- 		end
		-- 	end
	end
end

---@param callback fun(list: CompletionList|nil)
function M.complete(callback)
	vim.schedule(async.wrap(function()
		callback(complete())
	end))
end

return M
