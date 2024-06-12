local json = require("npackages.json")
local semver = require("npackages.semver")
local state = require("npackages.state")
local JsonPackageSyntax = json.JsonPackageSyntax
local types = require("npackages.types")
local Cond = types.Cond
local Span = types.Span
local SemVer = types.SemVer

local M = {}

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

return M
