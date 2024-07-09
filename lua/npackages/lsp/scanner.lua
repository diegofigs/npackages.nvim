local semver = require("npackages.lib.semver")

local M = {}

---@class JsonSection
---@field text string
---@field invalid boolean|nil
---@field workspace boolean|nil
---@field kind JsonSectionKind
---@field name_range lsp.Range|nil
---@field range lsp.Range
local Section = {}
M.Section = Section

---@enum JsonSectionKind
local JsonSectionKind = {
	DEFAULT = 1,
	DEV = 2,
	SCRIPTS = 3,
}
M.JsonSectionKind = JsonSectionKind

---@class JsonPackage
---@field explicit_name string
---@field range lsp.Range
---@field vers JsonPackageVers|nil
---@field workspace JsonPackageWorkspace|nil
---@field opt JsonPackageOpt|nil
---@field section JsonSection|nil
---@field dep_kind DepKind|nil
local Package = {}
M.Package = Package

---@class JsonPackageVers
---@field reqs Requirement[]?
---@field text string
---@field range lsp.Range
---@field quote lsp.Range

---@class JsonPackageWorkspace
---@field enabled boolean
---@field text string
---@field line integer -- 0-indexed
---@field range lsp.Range

---@class JsonPackageOpt
---@field enabled boolean
---@field text string
---@field line integer -- 0-indexed
---@field range lsp.Range

---@enum DepKind
local DepKind = {
	REGISTRY = 1,
	PATH = 2,
	GIT = 3,
	WORKSPACE = 4,
}
M.DepKind = DepKind

---@return JsonPackage
function Package.new(obj)
	if obj.vers then
		obj.vers.reqs = semver.parse_requirements(obj.vers.text)
	end
	if obj.workspace then
		obj.workspace.enabled = obj.workspace.text ~= "false"
	end
	if obj.opt then
		obj.opt.enabled = obj.opt.text ~= "false"
	end

	if obj.workspace then
		obj.dep_kind = DepKind.WORKSPACE
	elseif obj.path then
		obj.dep_kind = DepKind.PATH
	elseif obj.git then
		obj.dep_kind = DepKind.GIT
	else
		obj.dep_kind = DepKind.REGISTRY
	end

	return setmetatable(obj, { __index = Package })
end

---@return Requirement[]
function Package:vers_reqs()
	return self.vers and self.vers.reqs or {}
end

---@return boolean
function Package:is_workspace()
	return not self.workspace or self.workspace.enabled
end

---@return string
function Package:package()
	return self.explicit_name
end

---@return string
function Package:cache_key()
	return string.format("%s", self.explicit_name)
end

---@param obj JsonSection
---@return JsonSection
function Section.new(obj)
	return setmetatable(obj, { __index = Section })
end

---@param override_name string|nil
---@return string
function Section:display(override_name)
	local text = '"'

	if self.workspace then
		text = text .. "workspace."
	end

	if self.kind == JsonSectionKind.DEFAULT then
		text = text .. "dependencies"
	elseif self.kind == JsonSectionKind.DEV then
		text = text .. "devDependencies"
	elseif self.kind == JsonSectionKind.SCRIPTS then
		text = text .. "scripts"
	end

	if override_name then
		text = text .. "." .. override_name
	end

	text = text .. '"'

	return text
end

local function clean_version(value)
	if value == nil then
		return nil
	end

	local version = value:gsub("%^", ""):gsub("~", "")
	return version
end

local is_valid_dependency_version = function(value)
	local cleaned_version = clean_version(value)

	if cleaned_version == nil then
		return false
	end

	local position = 0
	local is_valid = true

	for chunk in string.gmatch(cleaned_version, "([^.]+)") do
		if position ~= 2 and type(tonumber(chunk)) ~= "number" then
			is_valid = false
		end

		position = position + 1
	end

	return is_valid
end

function M.get_dependency_name_from_line(line)
	local value = {}

	for chunk in string.gmatch(line, [["(.-)"]]) do
		table.insert(value, chunk)
	end

	if not value[1] or not value[2] then
		return nil
	end

	local is_valid_version = is_valid_dependency_version(value[2])

	if is_valid_version then
		return value[1]
	end

	return nil
end

---@param text string
---@param line_nr integer
---@param start integer
---@param kind JsonSectionKind
---@return JsonSection|nil
function M.scan_section(text, line_nr, start, kind)
	local prefix, suffix_s, suffix

	if kind == JsonSectionKind.DEFAULT then
		prefix, suffix_s, suffix = text:match("^(.*)dependencies()(.*)$")
	elseif kind == JsonSectionKind.DEV then
		prefix, suffix_s, suffix = text:match("^(.*)devDependencies()(.*)$")
	elseif kind == JsonSectionKind.SCRIPTS then
		prefix, suffix_s, suffix = text:match("^(.*)scripts()(.*)$")
	end

	if prefix and suffix then
		prefix = vim.trim(prefix)
		suffix = vim.trim(suffix)
		local section = {
			text = text,
			invalid = false,
			kind = kind,
			range = { start = { line = line_nr, character = start } },
		}

		section.invalid = prefix ~= ""
			or suffix ~= ""
			or (section.workspace and section.kind ~= JsonSectionKind.DEFAULT)

		section.name_range = {
			start = { line = line_nr, character = start },
			["end"] = { line = line_nr, character = start + suffix_s + 1 },
		}

		return Section.new(section)
	end

	return nil
end

---@param line string
---@param line_nr integer
---@return JsonPackage|nil
function M.scan_line(line, line_nr)
	do
		---@diagnostic disable-next-line: unused-local
		local name_s, name, name_e, quote_s, str_s, text, str_e, quote_e =
			line:match([[^%s*()%"([^%s]+)%"()%s*:%s*(["'])()([^"']*)()(["']?).*$]])
		if name then
			local obj = {
				explicit_name = name,
				range = {
					start = { line = line_nr, character = name_s - 1 },
					["end"] = { line = line_nr, character = name_e - 1 },
				},
				vers = {
					text = text,
					line = line_nr,
					range = {
						start = { line = line_nr, character = str_s - 1 },
						["end"] = { line = line_nr, character = str_e - 1 },
					},
					quote = {
						start = { line = line_nr, character = str_s - 2 },
						["end"] = { line = line_nr, character = str_e },
					},
				},
			}
			return Package.new(obj)
		end
	end

	return nil
end

---@class JsonScript
---@field name string
---@field range lsp.Range
---@field section JsonSection
local Script = {}
M.Script = Script

---@param line string
---@param line_nr integer
---@return JsonScript|nil
function M.scan_script(line, line_nr)
	---@diagnostic disable-next-line: unused-local
	local name_s, name, name_e, quote_s, cmd_s, command, cmd_e, quote_e =
		line:match([[^%s*()%"([^%s]+)%"()%s*:%s*(["'])()([^"']*)()(["']?).*$]])
	if name and command then
		return {
			name = name,
			range = {
				start = { line = line_nr, character = name_s - 1 },
				["end"] = { line = line_nr, character = name_e - 1 },
			},
		}
	end
	return nil
end

---@param lines string[]
---@return JsonSection[]
---@return JsonPackage[]
---@return JsonScript[]
function M.scan_package_doc(lines)
	local sections = {}
	local packages = {}
	local scripts = {}

	local dep_section
	local script_section

	for i, line in ipairs(lines) do
		local line_nr = i - 1

		local section_text = line:match('^.-%"(dependencies)%".-$')
		local dev_section_text = line:match('^.-%"(devDependencies)%".-$')
		local script_section_text = line:match('^.-%"(scripts)%".-$')
		local section_end = line:find("^.-%}.-$")
		local package_version = M.get_dependency_name_from_line(line)

		if section_text == "dependencies" then
			local section_start = line:find('("dependencies")')
			dep_section = M.scan_section(section_text, line_nr, section_start - 1, JsonSectionKind.DEFAULT)
		elseif dev_section_text == "devDependencies" then
			local section_start = line:find('("devDependencies")')
			dep_section = M.scan_section(dev_section_text, line_nr, section_start - 1, JsonSectionKind.DEV)
		elseif script_section_text == "scripts" then
			local section_start = line:find('("scripts")')
			script_section = M.scan_section(script_section_text, line_nr, section_start - 1, JsonSectionKind.SCRIPTS)
		end

		if dep_section and package_version then
			local pkg = M.scan_line(line, line_nr)
			if pkg then
				pkg.section = dep_section
				table.insert(packages, Package.new(pkg))
			end
		elseif script_section then
			local script = M.scan_script(line, line_nr)
			if script then
				script.section = script_section
				table.insert(scripts, script)
			end
		end

		if (dep_section or script_section) and section_end then
			local character = line:find("(})")
			if dep_section then
				dep_section.range["end"] =
					{ line = line_nr, character = character or dep_section.range.start.character }
				table.insert(sections, dep_section)
				dep_section = nil
			end
			if script_section then
				script_section.range["end"] =
					{ line = line_nr, character = character or script_section.range.start.character }
				table.insert(sections, script_section)
				script_section = nil
			end
		end
	end

	return sections, packages, scripts
end

return M
