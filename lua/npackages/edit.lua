local json = require("npackages.json")
local semver = require("npackages.semver")
local state = require("npackages.state")
local JsonPackageSyntax = json.JsonPackageSyntax
local types = require("npackages.types")
local Cond = types.Cond
local Span = types.Span
local SemVer = types.SemVer

local M = {}

---comment
---@param buf integer
---@param package JsonPackage
---@param name string
function M.rename_crate_package(buf, package, name)
	---@type integer, Span
	local line, col
	if package.pkg then
		line = package.pkg.line
		col = package.pkg.col
	else
		line = package.lines.s
		col = package.explicit_name_col
	end

	vim.api.nvim_buf_set_text(buf, line, col.s, line, col.e, { name })
end

---@param buf integer
---@param package JsonPackage
---@param text string
---@return Span
local function insert_version(buf, package, text)
	if not package.vers then
		if package.syntax == JsonPackageSyntax.TABLE then
			local line = package.lines.s + 1
			vim.api.nvim_buf_set_lines(buf, line, line, false, { 'version = "' .. text .. '"' })
			return package.lines:moved(0, 1)
		elseif package.syntax == JsonPackageSyntax.INLINE_TABLE then
			local line = package.lines.s
			local col = math.min(
				package.pkg and package.pkg.col.s or 999,
				package.def and package.def.col.s or 999,
				package.feat and package.def.col.s or 999,
				package.git and package.git.decl_col.s or 999,
				package.path and package.path.decl_col.s or 999
			)
			vim.api.nvim_buf_set_text(buf, line, col, line, col, { ' version = "' .. text .. '",' })
			return Span.pos(line)
		else -- crate.syntax == JsonPackageSyntax.PLAIN
			error("unreachable")
		end
	else
		local t = text
		if state.cfg.insert_closing_quote and not package.vers.quote.e then
			t = text .. package.vers.quote.s
		end
		local line = package.vers.line

		vim.api.nvim_buf_set_text(buf, line, package.vers.col.s, line, package.vers.col.e, { t })
		return Span.pos(line)
	end
end

---@param r Requirement
---@param version SemVer
---@return SemVer
local function replace_existing(r, version)
	if version.pre then
		return version
	else
		return SemVer.new({
			major = version.major,
			minor = r.vers.minor and version.minor or nil,
			patch = r.vers.patch and version.patch or nil,
		})
	end
end

---@param package JsonPackage
---@param version SemVer
---@return string
function M.smart_version_text(package, version)
	if #package:vers_reqs() == 0 then
		return version:display()
	end

	local pos = 1
	local text = ""
	for _, r in ipairs(package:vers_reqs()) do
		if r.cond == Cond.EQ then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.WL then
			if version.pre then
				text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. version:display()
			else
				local v = SemVer.new({
					major = r.vers.major and version.major or nil,
					minor = r.vers.minor and version.minor or nil,
				})
				local before = string.sub(package.vers.text, pos, r.vers_col.s)
				local after = string.sub(package.vers.text, r.vers_col.e + 1, r.cond_col.e)
				text = text .. before .. v:display() .. after
			end
		elseif r.cond == Cond.TL then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.CR then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.BL then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.LT and not semver.matches_requirement(version, r) then
			local v = SemVer.new({
				major = version.major,
				minor = r.vers.minor and version.minor or nil,
				patch = r.vers.patch and version.patch or nil,
			})

			if v.patch then
				v.patch = v.patch + 1
			elseif v.minor then
				v.minor = v.minor + 1
			elseif v.major then
				v.major = v.major + 1
			end

			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.LE and not semver.matches_requirement(version, r) then
			---@type SemVer
			local v

			if version.pre then
				v = version
			else
				v = SemVer.new({ major = version.major })
				if r.vers.minor or version.minor and version.minor > 0 then
					v.minor = version.minor
				end
				if r.vers.patch or version.patch and version.patch > 0 then
					v.minor = version.minor
					v.patch = version.patch
				end
			end

			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.GT and not semver.matches_requirement(version, r) then
			local v = SemVer.new({
				major = r.vers.major and version.major or nil,
				minor = r.vers.minor and version.minor or nil,
				patch = r.vers.patch and version.patch or nil,
			})

			if v.patch then
				v.patch = v.patch - 1
				if v.patch < 0 then
					v.patch = 0
					v.minor = v.minor - 1
				end
			elseif v.minor then
				v.minor = v.minor - 1
				if v.minor < 0 then
					v.minor = 0
					v.major = v.major - 1
				end
			elseif v.major then
				v.major = v.major - 1
				if v.major < 0 then
					v.major = 0
				end
			end

			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		elseif r.cond == Cond.GE then
			local v = replace_existing(r, version)
			text = text .. string.sub(package.vers.text, pos, r.vers_col.s) .. v:display()
		else
			text = text .. string.sub(package.vers.text, pos, r.vers_col.e)
		end

		pos = math.max(r.cond_col.e + 1, r.vers_col.e + 1)
	end
	text = text .. string.sub(package.vers.text, pos)

	return text
end

---@param package JsonPackage
---@param version SemVer
---@param alt boolean|nil
---@return string
function M.version_text(package, version, alt)
	local smart = alt ~= state.cfg.smart_insert
	if smart then
		return M.smart_version_text(package, version)
	else
		return version:display()
	end
end

---@param buf integer
---@param package JsonPackage
---@param version SemVer
---@param alt boolean|nil
---@return Span
function M.set_version(buf, package, version, alt)
	local text = M.version_text(package, version, alt)
	return insert_version(buf, package, text)
end

---@param buf integer
---@param packages table<string,JsonPackage>
---@param info table<string,PackageInfo>
---@param alt boolean|nil
function M.upgrade_packages(buf, packages, info, alt)
	for k, c in pairs(packages) do
		local i = info[k]

		if i then
			local version = i.vers_upgrade or i.vers_update
			if version then
				M.set_version(buf, c, version.parsed, alt)
			end
		end
	end
end

---@param buf integer
---@param packages table<string,JsonPackage>
---@param info table<string,PackageInfo>
---@param alt boolean|nil
function M.update_packages(buf, packages, info, alt)
	for k, c in pairs(packages) do
		local i = info[k]

		if i then
			local version = i.vers_update
			if version then
				M.set_version(buf, c, version.parsed, alt)
			end
		end
	end
end

---@param buf integer
---@param package JsonPackage
---@param feature TomlFeature
---@return Span
function M.disable_feature(buf, package, feature)
	-- check reference in case of duplicates
	---@type integer
	local index
	for i, f in ipairs(package.feat.items) do
		if f == feature then
			index = i
			break
		end
	end
	assert(index)

	local col_start = feature.decl_col.s
	local col_end = feature.decl_col.e
	if index == 1 then
		if #package.feat.items > 1 then
			col_end = package.feat.items[2].col.s - 1
		elseif feature.comma then
			col_end = col_end + 1
		end
	else
		local prev_feature = package.feat.items[index - 1]
		col_start = prev_feature.col.e + 1
	end

	vim.api.nvim_buf_set_text(
		buf,
		package.feat.line,
		package.feat.col.s + col_start,
		package.feat.line,
		package.feat.col.s + col_end,
		{ "" }
	)
	return Span.pos(package.feat.line)
end

---@param buf integer
---@param crate JsonPackage
---@return Span
function M.enable_def_features(buf, crate)
	vim.api.nvim_buf_set_text(buf, crate.def.line, crate.def.col.s, crate.def.line, crate.def.col.e, { "true" })
	return Span.pos(crate.def.line)
end

---@param buf integer
---@param crate JsonPackage
---@return Span
local function disable_def_features(buf, crate)
	if crate.def then
		local line = crate.def.line
		vim.api.nvim_buf_set_text(buf, line, crate.def.col.s, line, crate.def.col.e, { "false" })
		return crate.lines
	else
		if crate.syntax == JsonPackageSyntax.TABLE then
			local line = math.max(crate.vers and crate.vers.line + 1 or 0, crate.pkg and crate.pkg.line + 1 or 0)
			line = line ~= 0 and line
				or math.min(
					crate.feat and crate.feat.line or 999,
					crate.git and crate.git.line or 999,
					crate.path and crate.path.line or 999
				)
			vim.api.nvim_buf_set_lines(buf, line, line, false, { "default-features = false" })
			return crate.lines:moved(0, 1)
		elseif crate.syntax == JsonPackageSyntax.PLAIN then
			local t = ", default-features = false }"
			local col = crate.vers.col.e
			if crate.vers.quote.e then
				col = col + 1
			else
				t = crate.vers.quote.s .. t
			end
			local line = crate.vers.line
			vim.api.nvim_buf_set_text(buf, line, col, line, col, { t })

			vim.api.nvim_buf_set_text(buf, line, crate.vers.col.s - 1, line, crate.vers.col.s - 1, { "{ version = " })
			return crate.lines
		else -- if crate.syntax == JsonPackageSyntax.INLINE_TABLE then
			local line = crate.lines.s
			local text = ", default-features = false"
			local col = math.max(
				crate.vers and crate.vers.col.e + (crate.vers.quote.e and 1 or 0) or 0,
				crate.pkg and crate.pkg.col.e or 0
			)
			if col == 0 then
				text = " default-features = false,"
				col = math.min(
					crate.feat and crate.def.col.s or 999,
					crate.git and crate.git.decl_col.s or 999,
					crate.path and crate.path.decl_col.s or 999
				)
			end
			vim.api.nvim_buf_set_text(buf, line, col, line, col, { text })
			return crate.lines
		end
	end
end

---@param buf integer
---@param crate JsonPackage
---@param feature TomlFeature|nil
---@return Span
function M.disable_def_features(buf, crate, feature)
	if feature then
		if not crate.def or crate.def.col.s < crate.feat.col.s then
			M.disable_feature(buf, crate, feature)
			return disable_def_features(buf, crate)
		else
			local lines = disable_def_features(buf, crate)
			M.disable_feature(buf, crate, feature)
			return lines
		end
	else
		return disable_def_features(buf, crate)
	end
end

---@param buf integer
---@param crate JsonPackage
function M.expand_plain_crate_to_inline_table(buf, crate)
	if crate.syntax ~= JsonPackageSyntax.PLAIN then
		return
	end

	local text = crate.explicit_name .. ' = { version = "' .. crate.vers.text .. '" }'
	vim.api.nvim_buf_set_text(buf, crate.lines.s, crate.vers.decl_col.s, crate.lines.s, crate.vers.decl_col.e, { text })

	if state.cfg.expand_crate_moves_cursor then
		local pos = { crate.lines.s + 1, #text - 2 }
		vim.api.nvim_win_set_cursor(0, pos)
	end
end

return M
