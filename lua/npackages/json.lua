local get_dependency_name_from_line = require("npackages.utils.get_dependency_name_from_line")
local semver = require("npackages.semver")
local types = require("npackages.types")
local Span = types.Span

local M = {}

---@class JsonSection
---@field text string
---@field invalid boolean|nil
---@field workspace boolean|nil
---@field target string|nil
---@field kind JsonSectionKind
---@field name string|nil
---@field name_col Span|nil
---@field lines Span
local Section = {}
M.Section = Section

---@enum JsonSectionKind
local JsonSectionKind = {
	DEFAULT = 1,
	DEV = 2,
	BUILD = 3,
}
M.JsonSectionKind = JsonSectionKind

---@class JsonPackage
--- The explicit name is either the name of the package, or a rename
--- if the following syntax is used:
--- explicit_name = { package = "package" }
---@field explicit_name string
---@field explicit_name_col Span
---@field lines Span
---@field syntax JsonPackageSyntax
---@field vers JsonPackageVers|nil
---@field registry JsonPackageRegistry|nil
---@field path JsonPackagePath|nil
---@field git JsonPackageGit|nil
---@field branch JsonPackageBranch|nil
---@field rev JsonPackageRev|nil
---@field pkg JsonPackagePkg|nil
---@field workspace JsonPackageWorkspace|nil
---@field opt JsonPackageOpt|nil
---@field def JsonPackageDef|nil
---@field feat JsonPackageFeat|nil
---@field section JsonSection|nil
---@field dep_kind DepKind|nil
local Package = {}
M.Package = Package

---@enum JsonPackageSyntax
local JsonPackageSyntax = {
	PLAIN = 1,
	INLINE_TABLE = 2,
	TABLE = 3,
}
M.JsonPackageSyntax = JsonPackageSyntax

---@class JsonPackageVers
---@field reqs Requirement[]
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class JsonPackageRegistry
---@field text string
---@field is_pre boolean
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class JsonPackagePath
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class JsonPackageGit
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class JsonPackageBranch
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class JsonPackageRev
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class JsonPackagePkg
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span
---@field quote Quotes

---@class JsonPackageWorkspace
---@field enabled boolean
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span

---@class JsonPackageOpt
---@field enabled boolean
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span

---@class JsonPackageDef
---@field enabled boolean
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span

---@class JsonPackageFeat
---@field items TomlFeature[]
---@field text string
---@field line integer -- 0-indexed
---@field col Span
---@field decl_col Span

---@enum DepKind
local DepKind = {
	REGISTRY = 1,
	PATH = 2,
	GIT = 3,
	WORKSPACE = 4,
}
M.DepKind = DepKind

---@class TomlFeature
---@field name string
---relative to to the start of the features text
---@field col Span
---relative to to the start of the features text
---@field decl_col Span
---@field quote Quotes
---@field comma boolean
local TomlFeature = {}
M.TomlFeature = TomlFeature

---@class Quotes
---@field s string
---@field e string|nil

---@param text string
---@return TomlFeature[]
function M.parse_crate_features(text)
	---@type TomlFeature[]
	local feats = {}
	---@param fds integer
	---@param qs string
	---@param fs integer
	---@param f string
	---@param fe integer
	---@param qe string|nil
	---@param fde integer
	---@param c string|nil
	for fds, qs, fs, f, fe, qe, fde, c in text:gmatch([[[,]?()%s*(["'])()([^,"']*)()(["']?)%s*()([,]?)]]) do
		---@type TomlFeature
		local feat = {
			name = f,
			col = Span.new(fs - 1, fe - 1),
			decl_col = Span.new(fds - 1, fde - 1),
			quote = { s = qs, e = qe ~= "" and qe or nil },
			comma = c == ",",
		}
		table.insert(feats, feat)
	end

	return feats
end

---@param obj JsonPackage
---@return JsonPackage
function Package.new(obj)
	if obj.vers then
		obj.vers.reqs = semver.parse_requirements(obj.vers.text)
	end
	if obj.feat then
		obj.feat.items = M.parse_crate_features(obj.feat.text)
	end
	if obj.def then
		obj.def.enabled = obj.def.text ~= "false"
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

---@param name string
---@return TomlFeature|nil
---@return integer|nil
function Package:get_feat(name)
	if not self.feat or not self.feat.items then
		return nil, nil
	end

	for i, f in ipairs(self.feat.items) do
		if f.name == name then
			return f, i
		end
	end

	return nil, nil
end

---@return TomlFeature[]
function Package:feats()
	return self.feat and self.feat.items or {}
end

---@return boolean
function Package:is_def_enabled()
	return not self.def or self.def.enabled
end

---@return boolean
function Package:is_workspace()
	return not self.workspace or self.workspace.enabled
end

---@return string
function Package:package()
	return self.pkg and self.pkg.text or self.explicit_name
end

---@return string
function Package:cache_key()
	return string.format(
		-- "%s:%s:%s:%s",
		"%s",
		-- self.section.target or "",
		-- self.section.workspace and "workspace" or "",
		-- self.section.kind,
		self.explicit_name
	)
end

---@param obj JsonSection
---@return JsonSection
function Section.new(obj)
	return setmetatable(obj, { __index = Section })
end

---@param override_name string|nil
---@return string
function Section:display(override_name)
	local text = "["

	if self.target then
		text = text .. self.target .. "."
	end

	if self.workspace then
		text = text .. "workspace."
	end

	if self.kind == JsonSectionKind.DEFAULT then
		text = text .. "dependencies"
	elseif self.kind == JsonSectionKind.DEV then
		text = text .. "devDependencies"
		-- elseif self.kind == JsonSectionKind.BUILD then
		-- 	text = text .. "build-dependencies"
	end

	local name = override_name or self.name
	if name then
		text = text .. "." .. name
	end

	text = text .. "]"

	return text
end

---@param text string
---@param line_nr integer
---@param start integer
---@param kind JsonSectionKind
---@return JsonSection|nil
function M.parse_section(text, line_nr, start, kind)
	---@type string, integer, string
	local prefix, suffix_s, suffix

	if kind == JsonSectionKind.DEFAULT then
		prefix, suffix_s, suffix = text:match("^(.*)dependencies()(.*)$")
	else
		prefix, suffix_s, suffix = text:match("^(.*)devDependencies()(.*)$")
	end

	if prefix and suffix then
		prefix = vim.trim(prefix)
		suffix = vim.trim(suffix)
		---@type JsonSection
		local section = {
			text = text,
			invalid = false,
			kind = kind,
			---end bound is assigned when the section ends
			---@diagnostic disable-next-line: param-type-mismatch
			lines = Span.new(line_nr, nil),
		}

		local target = prefix

		-- local dev_target = prefix:match("^(.*)dev%-$")
		-- if dev_target then
		-- 	target = vim.trim(dev_target)
		-- 	section.kind = JsonSectionKind.DEV
		-- end
		--
		-- local build_target = prefix:match("^(.*)build%-$")
		-- if build_target then
		-- 	target = vim.trim(build_target)
		-- 	section.kind = JsonSectionKind.BUILD
		-- end
		--
		-- local workspace_target = target:match("^(.*)workspace%s*%.$")
		-- if workspace_target then
		-- 	section.workspace = true
		-- 	target = vim.trim(workspace_target)
		-- end
		--
		-- if target then
		-- 	local t = target:match("^target%s*%.(.+)%.$")
		-- 	if t then
		-- 		section.target = vim.trim(t)
		-- 		target = ""
		-- 	end
		-- end

		if suffix then
			local n_s, n, n_e = suffix:match("^%.%s*()(.+)()%s*$")
			if n then
				section.name = vim.trim(n)
				---@cast suffix_s number
				local offset = start + suffix_s - 1
				section.name_col = Span.new(n_s - 1 + offset, n_e - 1 + offset)
				suffix = ""
			end
		end

		section.invalid = (target ~= "" or suffix ~= "")
			or (section.workspace and section.kind ~= JsonSectionKind.DEFAULT)
			or (section.workspace and section.target ~= nil)

		return Section.new(section)
	end

	return nil
end

---comment
---@param line string
---@param line_nr integer
---@return JsonPackage|nil
function M.parse_inline_package(line, line_nr)
	-- plain version
	do
		local name_s, name, name_e, quote_s, str_s, text, str_e, quote_e =
			line:match([[^%s*()%"([^%s]+)%"()%s*:%s*(["'])()([^"']*)()(["']?).*$]])
		if name then
			---@type JsonPackage
			return Package.new({
				explicit_name = name,
				explicit_name_col = Span.new(name_s - 1, name_e - 1),
				lines = Span.new(line_nr, line_nr + 1),
				syntax = JsonPackageSyntax.PLAIN,
				vers = {
					text = text,
					line = line_nr,
					col = Span.new(str_s - 1, str_e - 1),
					decl_col = Span.new(0, line:len()),
					quote = { s = quote_s, e = quote_e ~= "" and quote_e or nil },
				},
			})
		end
	end

	return nil
end

---@param line string
---@return string
function M.trim_comments(line)
	local uncommented = line:match("^([^#]*)#.*$")
	return uncommented or line
end

---comment
---@param buf integer
---@return JsonSection[]
---@return JsonPackage[]
---@return WorkingCrate[]
function M.parse_packages(buf)
	---@type string[]
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	local sections = {}
	local packages = {}

	---@type JsonSection?
	local dep_section
	---@type WorkingCrate[]
	local working_crates = {}

	for i, line in ipairs(lines) do
		-- line = M.trim_comments(line)
		local line_nr = i - 1

		---@type string, string
		local section_text = line:match('^.-%"(dependencies)%".-$')
		local dev_section_text = line:match('^.-%"(devDependencies)%".-$')
		local section_end = line:find("^.-%}.-$")
		local package_version = get_dependency_name_from_line(line)

		---NOTE:
		--- iterate over every line (replicate for devDependencies):
		--- 1. on dependencies section match, initialize section
		--- 2. on package match, parse package and add to section
		--- 3. on section closure match, finalize section and nil it

		--- 1. dependency section
		if section_text == "dependencies" then
			local section_start = line:find('^.-%"(dependencies)%".-$')
			dep_section = M.parse_section(section_text, line_nr, section_start - 1, JsonSectionKind.DEFAULT)
		elseif dev_section_text == "devDependencies" then
			local section_start = line:find('^.-%"(devDependencies)%".-$')
			dep_section = M.parse_section(dev_section_text, line_nr, section_start - 1, JsonSectionKind.DEV)
		end

		--- 2. package line
		if dep_section and package_version then
			local crate = M.parse_inline_package(line, line_nr)
			if crate then
				crate.section = dep_section
				table.insert(packages, Package.new(crate))
			else
				local name = line:match([[^%s*%"([^%s]+)%"]])
				local name_s, name_e = line:find([[^%s*%"([^%s]+)%"]])
				if name_s and name and name_e then
					table.insert(working_crates, {
						name = name,
						line = line_nr,
						col = Span.new(name_s - 1, name_e - 1),
						kind = types.WorkingCrateKind.INLINE,
					})
				end
			end
		end
		--- 3. section closure
		if dep_section and section_end then
			dep_section.lines.e = line_nr
			table.insert(sections, dep_section)
			dep_section = nil
		end
	end

	return sections, packages, working_crates
end

return M
