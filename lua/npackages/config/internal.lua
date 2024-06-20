local M = {}

---@class SchemaType
---@field config_type ConfigType|ConfigType[]
---@field emmylua_annotation string

---@alias ConfigType
-- A record of grouped options
---| "section"
-- The rest are lua types checked at runtime
---| "table"
---| "string"
---| "number"
---| "boolean"
---| "function"

---@alias SchemaElement
---| SectionSchemaElement
---| HiddenSectionSchemaElement
---| FieldSchemaElement
---| HiddenFieldSchemaElement
---| DeprecatedSchemaElement

---@class SectionSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field description string
---@field fields table<string,SchemaElement>|SchemaElement[]

---@class HiddenSectionSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field fields table<string,SchemaElement>|SchemaElement[]
---@field hidden boolean

---@class FieldSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field default any
---@field default_text string|nil
---@field description string

---@class HiddenFieldSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field default any
---@field hidden boolean

---@class DeprecatedSchemaElement
---@field name string
---@field type SchemaType|SchemaType[]
---@field deprecated Deprecated|nil

---@class Deprecated
---@field new_field string[]|nil
---@field hard boolean|nil

---@param schema table<string,SchemaElement>|SchemaElement[]
---@param elem SchemaElement
local function entry(schema, elem)
	table.insert(schema, elem)
	schema[elem.name] = elem
end

---@param schema table<string,SchemaElement>|SchemaElement[]
---@param elem SectionSchemaElement|HiddenSectionSchemaElement
---@return table<string,SchemaElement>|SchemaElement[]
local function section_entry(schema, elem)
	table.insert(schema, elem)
	schema[elem.name] = elem
	return elem.fields
end

---@type SchemaType
local STRING_TYPE = {
	config_type = "string",
	emmylua_annotation = "string",
}

---@type SchemaType
local BOOLEAN_TYPE = {
	config_type = "boolean",
	emmylua_annotation = "boolean",
}

---@type SchemaType
local INTEGER_TYPE = {
	config_type = "number",
	emmylua_annotation = "integer",
}

---@type SchemaType
local STRING_ARRAY_TYPE = {
	config_type = "table",
	emmylua_annotation = "string[]",
}

M.schema = {}
entry(M.schema, {
	name = "smart_insert",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Try to be smart about inserting versions, by respecting existing version requirements.

        Example: ~

            Existing requirement:
            `>0.8, <1.3`

            Version to insert:
            `1.5.4`

            Resulting requirement:
            `>0.8, <1.6`
    ]],
})
entry(M.schema, {
	name = "insert_closing_quote",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Insert a closing quote when updating or upgrading a version, if there is none.
    ]],
})
entry(M.schema, {
	name = "autoload",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Automatically run update when opening a package.json.
    ]],
})
entry(M.schema, {
	name = "autoupdate",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Automatically update when editing text.
    ]],
})
entry(M.schema, {
	name = "autostart",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Automatically start lsp.
    ]],
})
entry(M.schema, {
	name = "autoupdate_throttle",
	type = INTEGER_TYPE,
	default = 250,
	description = [[
        Rate limit the auto update in milliseconds
    ]],
})
entry(M.schema, {
	name = "loading_indicator",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Show a loading indicator while fetching package versions.
    ]],
})
entry(M.schema, {
	name = "date_format",
	type = STRING_TYPE,
	default = "%Y-%m-%d",
	description = [[
        The date format passed to `os.date`.
    ]],
})
entry(M.schema, {
	name = "thousands_separator",
	type = STRING_TYPE,
	default = ".",
	description = [[
        The separator used to separate thousands of a number:

        Example: ~
            Dot:
            `14.502.265`

            Comma:
            `14,502,265`
    ]],
})
entry(M.schema, {
	name = "notification_title",
	type = STRING_TYPE,
	default = "npackages.nvim",
	description = [[
        The title displayed in notifications.
    ]],
})
entry(M.schema, {
	name = "curl_args",
	type = STRING_ARRAY_TYPE,
	default = { "-sL", "--retry", "1" },
	description = [[
        A list of arguments passed to curl when fetching metadata from packages.io.
    ]],
})
entry(M.schema, {
	name = "max_parallel_requests",
	type = INTEGER_TYPE,
	default = 80,
	description = [[
        Maximum number of parallel requests.
    ]],
})
entry(M.schema, {
	name = "open_programs",
	type = STRING_ARRAY_TYPE,
	default = { "xdg-open", "open" },
	description = [[
        A list of programs that used to open urls.
    ]],
})
entry(M.schema, {
	name = "expand_crate_moves_cursor",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Whether to move the cursor on |crates.expand_plain_crate_to_inline_table()|.
    ]],
})
entry(M.schema, {
	name = "enable_update_available_warning",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Enable warnings for outdated packages.
    ]],
})
entry(M.schema, {
	name = "on_attach",
	type = {
		config_type = "function",
		emmylua_annotation = "fun(bufnr: integer)",
	},
	default = function(_) end,
	default_text = "function(bufnr) end",
	description = [[
        Callback to run when a `package.json` file is opened.

        NOTE: Ignored if |crates-config-autoload| is disabled.
    ]],
})
-- deprecated
entry(M.schema, {
	name = "avoid_prerelease",
	type = BOOLEAN_TYPE,
	deprecated = {
		hard = true,
	},
})

local schema_text = section_entry(M.schema, {
	name = "text",
	type = {
		config_type = "section",
		emmylua_annotation = "TextConfig",
	},
	description = [[
        Strings used to format virtual text.
    ]],
	fields = {},
})
entry(schema_text, {
	name = "loading",
	type = STRING_TYPE,
	default = "   Loading",
	description = [[
        Format string used while loading package information.
    ]],
})
entry(schema_text, {
	name = "version",
	type = STRING_TYPE,
	default = "   %s",
	description = [[
        format string used for the latest compatible version
    ]],
})
entry(schema_text, {
	name = "prerelease",
	type = STRING_TYPE,
	default = "   %s",
	description = [[
        Format string used for pre-release versions.
    ]],
})
entry(schema_text, {
	name = "yanked",
	type = STRING_TYPE,
	default = "   %s",
	description = [[
        Format string used for yanked versions.
    ]],
})
entry(schema_text, {
	name = "nomatch",
	type = STRING_TYPE,
	default = "   No match",
	description = [[
        Format string used when there is no matching version.
    ]],
})
entry(schema_text, {
	name = "upgrade",
	type = STRING_TYPE,
	default = "   %s",
	description = [[
        Format string used when there is an upgrade candidate.
    ]],
})
entry(schema_text, {
	name = "error",
	type = STRING_TYPE,
	default = "   Error fetching package",
	description = [[
        Format string used when there was an error loading package information.
    ]],
})

local schema_hl = section_entry(M.schema, {
	name = "highlight",
	type = {
		config_type = "section",
		emmylua_annotation = "HighlightConfig",
	},
	description = [[
        Highlight groups used for virtual text.
    ]],
	fields = {},
})
entry(schema_hl, {
	name = "loading",
	type = STRING_TYPE,
	default = "NpackagesNvimLoading",
	description = [[
        Highlight group used while loading package information.
    ]],
})
entry(schema_hl, {
	name = "version",
	type = STRING_TYPE,
	default = "NpackagesNvimVersion",
	description = [[
        Highlight group used for the latest compatible version.
    ]],
})
entry(schema_hl, {
	name = "prerelease",
	type = STRING_TYPE,
	default = "NpackagesNvimPreRelease",
	description = [[
        Highlight group used for pre-release versions.
    ]],
})
entry(schema_hl, {
	name = "yanked",
	type = STRING_TYPE,
	default = "NpackagesNvimYanked",
	description = [[
        Highlight group used for yanked versions.
    ]],
})
entry(schema_hl, {
	name = "nomatch",
	type = STRING_TYPE,
	default = "NpackagesNvimNoMatch",
	description = [[
        Highlight group used when there is no matching version.
    ]],
})
entry(schema_hl, {
	name = "upgrade",
	type = STRING_TYPE,
	default = "NpackagesNvimUpgrade",
	description = [[
        Highlight group used when there is an upgrade candidate.
    ]],
})
entry(schema_hl, {
	name = "error",
	type = STRING_TYPE,
	default = "NpackagesNvimError",
	description = [[
        Highlight group used when there was an error loading package information.
    ]],
})

local schema_diagnostic = section_entry(M.schema, {
	name = "diagnostic",
	type = {
		config_type = "section",
		emmylua_annotation = "DiagnosticConfig",
	},
	fields = {},
	hidden = true,
})
entry(schema_diagnostic, {
	name = "section_invalid",
	type = STRING_TYPE,
	default = "Invalid dependency section",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "workspace_section_not_default",
	type = STRING_TYPE,
	default = "Workspace dependency sections don't support other kinds of dependencies like build or dev",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "workspace_section_has_target",
	type = STRING_TYPE,
	default = "Workspace dependency sections don't support target specifiers",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "section_dup",
	type = STRING_TYPE,
	default = "Duplicate dependency section",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "section_dup_orig",
	type = STRING_TYPE,
	default = "Original dependency section is first defined here",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "package_dup",
	type = STRING_TYPE,
	default = "Duplicate package",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "package_dup_orig",
	type = STRING_TYPE,
	default = "Original package is first defined here",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "package_novers",
	type = STRING_TYPE,
	default = "Missing version requirement",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "package_error_fetching",
	type = STRING_TYPE,
	default = "Error fetching package",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "package_name_case",
	type = STRING_TYPE,
	default = "Incorrect package name casing",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "vers_upgrade",
	type = STRING_TYPE,
	default = "Upgrade available",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "vers_pre",
	type = STRING_TYPE,
	default = "Requirement only matches a pre-release version\nIf you want to use the pre-release package, it needs to be specified explicitly",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "vers_yanked",
	type = STRING_TYPE,
	default = "Requirement only matches a yanked version",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "vers_nomatch",
	type = STRING_TYPE,
	default = "Requirement doesn't match a version",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "def_invalid",
	type = STRING_TYPE,
	default = "Invalid boolean value",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "feat_dup",
	type = STRING_TYPE,
	default = "Duplicate feature entry",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "feat_dup_orig",
	type = STRING_TYPE,
	default = "Original feature entry is defined here",
	hidden = true,
})
entry(schema_diagnostic, {
	name = "feat_invalid",
	type = STRING_TYPE,
	default = "Invalid feature",
	hidden = true,
})

local schema_popup = section_entry(M.schema, {
	name = "popup",
	type = {
		config_type = "section",
		emmylua_annotation = "PopupConfig",
	},
	description = [[
        Popup configuration.
    ]],
	fields = {},
})
entry(schema_popup, {
	name = "autofocus",
	type = BOOLEAN_TYPE,
	default = false,
	description = [[
        Focus the versions popup when opening it.
    ]],
})
entry(schema_popup, {
	name = "hide_on_select",
	type = BOOLEAN_TYPE,
	default = false,
	description = [[
        Hides the popup after selecting a version.
    ]],
})
entry(schema_popup, {
	name = "copy_register",
	type = STRING_TYPE,
	default = '"',
	description = [[
        The register into which the version will be copied.
    ]],
})
entry(schema_popup, {
	name = "style",
	type = STRING_TYPE,
	default = "minimal",
	description = [[
        Same as nvim_open_win config.style.
    ]],
})
entry(schema_popup, {
	name = "border",
	type = {
		config_type = { "string", "table" },
		emmylua_annotation = "string|string[]",
	},
	default = "none",
	description = [[
        Same as nvim_open_win config.border.
    ]],
})
entry(schema_popup, {
	name = "show_version_date",
	type = BOOLEAN_TYPE,
	default = false,
	description = [[
        Display when a version was released.
    ]],
})
entry(schema_popup, {
	name = "show_dependency_version",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Display when a version was released.
    ]],
})
entry(schema_popup, {
	name = "max_height",
	type = INTEGER_TYPE,
	default = 30,
	description = [[
        The maximum height of the popup.
    ]],
})
entry(schema_popup, {
	name = "min_width",
	type = INTEGER_TYPE,
	default = 20,
	description = [[
        The minimum width of the popup.
    ]],
})
entry(schema_popup, {
	name = "padding",
	type = INTEGER_TYPE,
	default = 1,
	description = [[
        The horizontal padding of the popup.
    ]],
})
-- deprecated
entry(schema_popup, {
	name = "version_date",
	type = BOOLEAN_TYPE,
	deprecated = {
		new_field = { "popup", "show_version_date" },
		hard = true,
	},
})

local schema_popup_text = section_entry(schema_popup, {
	name = "text",
	type = {
		config_type = "section",
		emmylua_annotation = "PopupTextConfig",
	},
	description = [[
        Strings used to format the text inside the popup.
    ]],
	fields = {},
})
entry(schema_popup_text, {
	name = "title",
	type = STRING_TYPE,
	default = " %s",
	description = [[
        Format string used for the popup title.
    ]],
})
entry(schema_popup_text, {
	name = "pill_left",
	type = STRING_TYPE,
	default = "",
	description = [[
        Left border of a pill (keywords and categories).
    ]],
})
entry(schema_popup_text, {
	name = "pill_right",
	type = STRING_TYPE,
	default = "",
	description = [[
        Right border of a pill (keywords and categories).
    ]],
})
-- package
entry(schema_popup_text, {
	name = "description",
	type = STRING_TYPE,
	default = "%s",
	description = [[
        Format string used for the description.
    ]],
})
entry(schema_popup_text, {
	name = "created_label",
	type = STRING_TYPE,
	default = " created        ",
	description = [[
        Label string used for the creation date.
    ]],
})
entry(schema_popup_text, {
	name = "created",
	type = STRING_TYPE,
	default = "%s",
	description = [[
        Format string used for the creation date.
    ]],
})
entry(schema_popup_text, {
	name = "updated_label",
	type = STRING_TYPE,
	default = " updated        ",
	description = [[
        Label string used for the updated date.
    ]],
})
entry(schema_popup_text, {
	name = "updated",
	type = STRING_TYPE,
	default = "%s",
	description = [[
        Format string used for the updated date.
    ]],
})
entry(schema_popup_text, {
	name = "downloads_label",
	type = STRING_TYPE,
	default = " downloads      ",
	description = [[
        Label string used for the download count.
    ]],
})
entry(schema_popup_text, {
	name = "downloads",
	type = STRING_TYPE,
	default = "%s",
	description = [[
        Format string used for the download count.
    ]],
})
entry(schema_popup_text, {
	name = "homepage_label",
	type = STRING_TYPE,
	default = " homepage       ",
	description = [[
        Label string used for the homepage url.
    ]],
})
entry(schema_popup_text, {
	name = "homepage",
	type = STRING_TYPE,
	default = "%s",
	description = [[
        Format string used for the homepage url.
    ]],
})
entry(schema_popup_text, {
	name = "repository_label",
	type = STRING_TYPE,
	default = " repository     ",
	description = [[
        Label string used for the repository url.
    ]],
})
entry(schema_popup_text, {
	name = "repository",
	type = STRING_TYPE,
	default = "%s",
	description = [[
        Format string used for the repository url.
    ]],
})
entry(schema_popup_text, {
	name = "documentation_label",
	type = STRING_TYPE,
	default = " documentation  ",
	description = [[
        Label string used for the documentation url.
    ]],
})
entry(schema_popup_text, {
	name = "documentation",
	type = STRING_TYPE,
	default = "%s",
	description = [[
        Format string used for the documentation url.
    ]],
})
entry(schema_popup_text, {
	name = "crates_io_label",
	type = STRING_TYPE,
	default = " npmjs.com      ",
	description = [[
        Label string used for the packages.io url.
    ]],
})
entry(schema_popup_text, {
	name = "crates_io",
	type = STRING_TYPE,
	default = "%s",
	description = [[
        Format string used for the packages.io url.
    ]],
})
entry(schema_popup_text, {
	name = "lib_rs_label",
	type = STRING_TYPE,
	default = " lib.rs         ",
	description = [[
        Label string used for the lib.rs url.
    ]],
})
entry(schema_popup_text, {
	name = "lib_rs",
	type = STRING_TYPE,
	default = "%s",
	description = [[
        Format string used for the lib.rs url.
    ]],
})
entry(schema_popup_text, {
	name = "categories_label",
	type = STRING_TYPE,
	default = " categories     ",
	description = [[
        Label string used for the categories label.
    ]],
})
entry(schema_popup_text, {
	name = "keywords_label",
	type = STRING_TYPE,
	default = " keywords       ",
	description = [[
        Label string used for the keywords label.
    ]],
})
-- versions
entry(schema_popup_text, {
	name = "version",
	type = STRING_TYPE,
	default = "  %s",
	description = [[
        Format string used for release versions.
    ]],
})
entry(schema_popup_text, {
	name = "prerelease",
	type = STRING_TYPE,
	default = " %s",
	description = [[
        Format string used for prerelease versions.
    ]],
})
entry(schema_popup_text, {
	name = "yanked",
	type = STRING_TYPE,
	default = " %s",
	description = [[
        Format string used for yanked versions.
    ]],
})
entry(schema_popup_text, {
	name = "version_date",
	type = STRING_TYPE,
	default = "  %s",
	description = [[
        Format string used for appending the version release date.
    ]],
})
-- features
entry(schema_popup_text, {
	name = "feature",
	type = STRING_TYPE,
	default = "  %s",
	description = [[
        Format string used for disabled features.
    ]],
})
entry(schema_popup_text, {
	name = "enabled",
	type = STRING_TYPE,
	default = " %s",
	description = [[
        Format string used for enabled features.
    ]],
})
entry(schema_popup_text, {
	name = "transitive",
	type = STRING_TYPE,
	default = " %s",
	description = [[
        Format string used for transitively enabled features.
    ]],
})
-- dependencies
entry(schema_popup_text, {
	name = "normal_dependencies_title",
	type = STRING_TYPE,
	default = " Dependencies",
	description = [[
        Format string used for the title of the normal dependencies section.
    ]],
})
entry(schema_popup_text, {
	name = "build_dependencies_title",
	type = STRING_TYPE,
	default = " Build dependencies",
	description = [[
        Format string used for the title of the build dependencies section.
    ]],
})
entry(schema_popup_text, {
	name = "dev_dependencies_title",
	type = STRING_TYPE,
	default = " Dev dependencies",
	description = [[
        Format string used for the title of the dev dependencies section.
    ]],
})
entry(schema_popup_text, {
	name = "dependency",
	type = STRING_TYPE,
	default = "  %s",
	description = [[
        Format string used for dependencies and their version requirement.
    ]],
})
entry(schema_popup_text, {
	name = "optional",
	type = STRING_TYPE,
	default = " %s",
	description = [[
        Format string used for optional dependencies and their version requirement.
    ]],
})
entry(schema_popup_text, {
	name = "dependency_version",
	type = STRING_TYPE,
	default = "  %s",
	description = [[
        Format string used for appending the dependency version.
    ]],
})
entry(schema_popup_text, {
	name = "loading",
	type = STRING_TYPE,
	default = "  ",
	description = [[
        Format string used as a loading indicator when fetching dependencies.
    ]],
})
-- deprecated
entry(schema_popup_text, {
	name = "date",
	type = STRING_TYPE,
	deprecated = {
		new_field = { "popup", "text", "version_date" },
		hard = true,
	},
})

local schema_popup_hl = section_entry(schema_popup, {
	name = "highlight",
	type = {
		config_type = "section",
		emmylua_annotation = "PopupHighlightConfig",
	},
	description = [[
        Highlight groups for popup elements.
    ]],
	fields = {},
})
entry(schema_popup_hl, {
	name = "title",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupTitle",
	description = [[
        Highlight group used for the popup title.
    ]],
})
entry(schema_popup_hl, {
	name = "pill_text",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupPillText",
	description = [[
        Highlight group used for a pill's text (keywords and categories).
    ]],
})
entry(schema_popup_hl, {
	name = "pill_border",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupPillBorder",
	description = [[
        Highlight group used for a pill's border (keywords and categories).
    ]],
})
-- package
entry(schema_popup_hl, {
	name = "description",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupDescription",
	description = [[
        Highlight group used for the package description.
    ]],
})
entry(schema_popup_hl, {
	name = "created_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the creation date label.
    ]],
})
entry(schema_popup_hl, {
	name = "created",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupValue",
	description = [[
        Highlight group used for the creation date.
    ]],
})
entry(schema_popup_hl, {
	name = "updated_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the updated date label.
    ]],
})
entry(schema_popup_hl, {
	name = "updated",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupValue",
	description = [[
        Highlight group used for the updated date.
    ]],
})
entry(schema_popup_hl, {
	name = "downloads_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the download count label.
    ]],
})
entry(schema_popup_hl, {
	name = "downloads",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupValue",
	description = [[
        Highlight group used for the download count.
    ]],
})
entry(schema_popup_hl, {
	name = "homepage_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the homepage url label.
    ]],
})
entry(schema_popup_hl, {
	name = "homepage",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupUrl",
	description = [[
        Highlight group used for the homepage url.
    ]],
})
entry(schema_popup_hl, {
	name = "repository_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the repository url label.
    ]],
})
entry(schema_popup_hl, {
	name = "repository",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupUrl",
	description = [[
        Highlight group used for the repository url.
    ]],
})
entry(schema_popup_hl, {
	name = "documentation_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the documentation url label.
    ]],
})
entry(schema_popup_hl, {
	name = "documentation",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupUrl",
	description = [[
        Highlight group used for the documentation url.
    ]],
})
entry(schema_popup_hl, {
	name = "crates_io_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the packages.io url label.
    ]],
})
entry(schema_popup_hl, {
	name = "crates_io",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupUrl",
	description = [[
        Highlight group used for the packages.io url.
    ]],
})
entry(schema_popup_hl, {
	name = "lib_rs_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the lib.rs url label.
    ]],
})
entry(schema_popup_hl, {
	name = "lib_rs",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupUrl",
	description = [[
        Highlight group used for the lib.rs url.
    ]],
})
entry(schema_popup_hl, {
	name = "categories_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the categories label.
    ]],
})
entry(schema_popup_hl, {
	name = "keywords_label",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLabel",
	description = [[
        Highlight group used for the keywords label.
    ]],
})
-- versions
entry(schema_popup_hl, {
	name = "version",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupVersion",
	description = [[
        Highlight group used for versions inside the popup.
    ]],
})
entry(schema_popup_hl, {
	name = "prerelease",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupPreRelease",
	description = [[
        Highlight group used for pre-release versions inside the popup.
    ]],
})
entry(schema_popup_hl, {
	name = "yanked",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupYanked",
	description = [[
        Highlight group used for yanked versions inside the popup.
    ]],
})
entry(schema_popup_hl, {
	name = "version_date",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupVersionDate",
	description = [[
        Highlight group used for the version date inside the popup.
    ]],
})
-- features
entry(schema_popup_hl, {
	name = "feature",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupFeature",
	description = [[
        Highlight group used for disabled features inside the popup.
    ]],
})
entry(schema_popup_hl, {
	name = "enabled",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupEnabled",
	description = [[
        Highlight group used for enabled features inside the popup.
    ]],
})
entry(schema_popup_hl, {
	name = "transitive",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupTransitive",
	description = [[
        Highlight group used for transitively enabled features inside the popup.
    ]],
})
-- dependencies
entry(schema_popup_hl, {
	name = "normal_dependencies_title",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupNormalDependenciesTitle",
	description = [[
        Highlight group used for the title of the normal dependencies section.
    ]],
})
entry(schema_popup_hl, {
	name = "build_dependencies_title",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupBuildDependenciesTitle",
	description = [[
        Highlight group used for the title of the build dependencies section.
    ]],
})
entry(schema_popup_hl, {
	name = "dev_dependencies_title",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupDevDependenciesTitle",
	description = [[
        Highlight group used for the title of the dev dependencies section.
    ]],
})
entry(schema_popup_hl, {
	name = "dependency",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupDependency",
	description = [[
        Highlight group used for dependencies inside the popup.
    ]],
})
entry(schema_popup_hl, {
	name = "optional",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupOptional",
	description = [[
        Highlight group used for optional dependencies inside the popup.
    ]],
})
entry(schema_popup_hl, {
	name = "dependency_version",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupDependencyVersion",
	description = [[
        Highlight group used for the dependency version inside the popup.
    ]],
})
entry(schema_popup_hl, {
	name = "loading",
	type = STRING_TYPE,
	default = "NpackagesNvimPopupLoading",
	description = [[
        Highlight group for the loading indicator inside the popup.
    ]],
})

local schema_popup_keys = section_entry(schema_popup, {
	name = "keys",
	type = {
		config_type = "section",
		emmylua_annotation = "PopupKeyConfig",
	},
	description = [[
        Key mappings inside the popup.
    ]],
	fields = {},
})
entry(schema_popup_keys, {
	name = "hide",
	type = STRING_ARRAY_TYPE,
	default = { "q", "<esc>" },
	description = [[
        Hides the popup.
    ]],
})
-- package
entry(schema_popup_keys, {
	name = "open_url",
	type = STRING_ARRAY_TYPE,
	default = { "<cr>" },
	description = [[
        Key mappings to open the url on the current line.
    ]],
})
-- versions
entry(schema_popup_keys, {
	name = "select",
	type = STRING_ARRAY_TYPE,
	default = { "<cr>" },
	description = [[
        Key mappings to insert the version respecting the |crates-config-smart_insert| flag.
    ]],
})
entry(schema_popup_keys, {
	name = "select_alt",
	type = STRING_ARRAY_TYPE,
	default = { "s" },
	description = [[
        Key mappings to insert the version using the opposite of |crates-config-smart_insert| flag.
    ]],
})
-- features
entry(schema_popup_keys, {
	name = "toggle_feature",
	type = STRING_ARRAY_TYPE,
	default = { "<cr>" },
	description = [[
        Key mappings to enable or disable the feature on the current line inside the popup.
    ]],
})
-- common
entry(schema_popup_keys, {
	name = "copy_value",
	type = STRING_ARRAY_TYPE,
	default = { "yy" },
	description = [[
        Key mappings to copy the value on the current line inside the popup.
    ]],
})
entry(schema_popup_keys, {
	name = "goto_item",
	type = STRING_ARRAY_TYPE,
	default = { "gd", "K", "<C-LeftMouse>" },
	description = [[
        Key mappings to go to the item on the current line inside the popup.
    ]],
})
entry(schema_popup_keys, {
	name = "jump_forward",
	type = STRING_ARRAY_TYPE,
	default = { "<c-i>" },
	description = [[
        Key mappings to jump forward in the popup jump history.
    ]],
})
entry(schema_popup_keys, {
	name = "jump_back",
	type = STRING_ARRAY_TYPE,
	default = { "<c-o>", "<C-RightMouse>" },
	description = [[
        Key mappings to go back in the popup jump history.
    ]],
})
-- deprecated
entry(schema_popup_keys, {
	name = "goto_feature",
	type = STRING_ARRAY_TYPE,
	deprecated = {
		new_field = { "popup", "keys", "goto_item" },
		hard = true,
	},
})
entry(schema_popup_keys, {
	name = "jump_forward_feature",
	type = STRING_ARRAY_TYPE,
	deprecated = {
		new_field = { "popup", "keys", "jump_forward" },
		hard = true,
	},
})
entry(schema_popup_keys, {
	name = "jump_back_feature",
	type = STRING_ARRAY_TYPE,
	deprecated = {
		new_field = { "popup", "keys", "jump_back" },
		hard = true,
	},
})
entry(schema_popup_keys, {
	name = "copy_version",
	type = STRING_ARRAY_TYPE,
	deprecated = {
		new_field = { "popup", "keys", "copy_value" },
		hard = true,
	},
})

local schema_completion = section_entry(M.schema, {
	name = "completion",
	type = {
		config_type = "section",
		emmylua_annotation = "CompletionConfig",
	},
	description = [[
        Configuration options for completion sources.
    ]],
	fields = {},
})
entry(schema_completion, {
	name = "insert_closing_quote",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Insert a closing quote on completion if there is none.
    ]],
})
local schema_completion_text = section_entry(schema_completion, {
	name = "text",
	type = {
		config_type = "section",
		emmylua_annotation = "CompletionTextConfig",
	},
	description = [[
        Text shown in the completion source documentation preview.
    ]],
	fields = {},
})
entry(schema_completion_text, {
	name = "prerelease",
	type = STRING_TYPE,
	default = "  pre-release ",
	description = [[
        Text shown in the completion source documentation preview for pre-release versions.
    ]],
})
entry(schema_completion_text, {
	name = "yanked",
	type = STRING_TYPE,
	default = "  yanked ",
	description = [[
        Text shown in the completion source documentation preview for yanked versions.
    ]],
})

local schema_completion_cmp = section_entry(schema_completion, {
	name = "cmp",
	type = {
		config_type = "section",
		emmylua_annotation = "CmpConfig",
	},
	description = [[
        Configuration options for the |nvim-cmp| completion source.
    ]],
	fields = {},
})
entry(schema_completion_cmp, {
	name = "enabled",
	type = BOOLEAN_TYPE,
	default = false,
	description = [[
        Whether to load and register the |nvim-cmp| source.

        NOTE: Ignored if |crates-config-autoload| is disabled.
        You may manually register it, after |nvim-cmp| has been loaded.
        >
            require("npackages.completion.cmp").setup()
        <
    ]],
})
entry(schema_completion_cmp, {
	name = "use_custom_kind",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Use custom a custom kind to display inside the |nvim-cmp| completion menu.
    ]],
})

local schema_completion_cmp_kind_text = section_entry(schema_completion_cmp, {
	name = "kind_text",
	type = {
		config_type = "section",
		emmylua_annotation = "CmpKindTextConfig",
	},
	description = [[
        The kind text shown in the |nvim-cmp| completion menu.
    ]],
	fields = {},
})
entry(schema_completion_cmp_kind_text, {
	name = "version",
	type = STRING_TYPE,
	default = "Version",
	description = [[
        The version kind text shown in the |nvim-cmp| completion menu.
    ]],
})
entry(schema_completion_cmp_kind_text, {
	name = "feature",
	type = STRING_TYPE,
	default = "Feature",
	description = [[
        The feature kind text shown in the |nvim-cmp| completion menu.
    ]],
})

local schema_completion_cmp_kind_hl = section_entry(schema_completion_cmp, {
	name = "kind_highlight",
	type = {
		config_type = "section",
		emmylua_annotation = "CmpKindHighlightConfig",
	},
	description = [[
        Highlight groups used for the kind text in the |nvim-cmp| completion menu.
    ]],
	fields = {},
})
entry(schema_completion_cmp_kind_hl, {
	name = "version",
	type = STRING_TYPE,
	default = "CmpItemKindVersion",
	description = [[
        Highlight group used for the version kind text in the |nvim-cmp| completion menu.
    ]],
})
entry(schema_completion_cmp_kind_hl, {
	name = "package",
	type = STRING_TYPE,
	default = "CmpItemKindPackage",
	description = [[
        Highlight group used for the package kind text in the |nvim-cmp| completion menu.
    ]],
})

local schema_completion_coq = section_entry(schema_completion, {
	name = "coq",
	type = {
		config_type = "section",
		emmylua_annotation = "CoqConfig",
	},
	description = [[
        Configuration options for the |coq_nvim| completion source.
    ]],
	fields = {},
})
entry(schema_completion_coq, {
	name = "enabled",
	type = BOOLEAN_TYPE,
	default = false,
	description = [[
        Whether to load and register the |coq_nvim| source.
    ]],
})
entry(schema_completion_coq, {
	name = "name",
	type = STRING_TYPE,
	default = "npackages.nvim",
	description = [[
        The source name displayed by |coq_nvim|.
    ]],
})

local schema_completion_crates = section_entry(schema_completion, {
	name = "npackages",
	type = {
		config_type = "section",
		emmylua_annotation = "PackageCompletionConfig",
	},
	description = [[
        Settings for completing the names of packages.
    ]],
	fields = {},
})
entry(schema_completion_crates, {
	name = "enabled",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Enable completing package names from crates.io search results.
    ]],
})
entry(schema_completion_crates, {
	name = "min_chars",
	type = INTEGER_TYPE,
	default = 3,
	description = [[
        The minimum number of characters of a package name you need to
        type before the plugin tries to complete the package name.
    ]],
})
entry(schema_completion_crates, {
	name = "max_results",
	type = INTEGER_TYPE,
	default = 8,
	description = [[
        The maximum number of visible results when attempting to
        complete a package name.
    ]],
})

local schema_null_ls = section_entry(M.schema, {
	name = "null_ls",
	type = {
		config_type = "section",
		emmylua_annotation = "NullLsConfig",
	},
	description = [[
        Configuration options for null-ls.nvim actions.
    ]],
	fields = {},
})
entry(schema_null_ls, {
	name = "enabled",
	type = BOOLEAN_TYPE,
	default = false,
	description = [[
        Whether to register the |null-ls.nvim| source.
    ]],
})
entry(schema_null_ls, {
	name = "name",
	type = STRING_TYPE,
	default = "npackages.nvim",
	description = [[
        The |null-ls.nvim| name.
    ]],
})

local schema_lsp = section_entry(M.schema, {
	name = "lsp",
	type = {
		config_type = "section",
		emmylua_annotation = "LspConfig",
	},
	description = [[
        Configuration options for the in-process language server.
    ]],
	fields = {},
})
entry(schema_lsp, {
	name = "enabled",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Whether to enable the in-process language server.
    ]],
})
entry(schema_lsp, {
	name = "name",
	type = STRING_TYPE,
	default = "npackages_ls",
	description = [[
        The lsp server name.
    ]],
})
entry(schema_lsp, {
	name = "on_attach",
	type = {
		config_type = "function",
		emmylua_annotation = "fun(client: vim.lsp.Client, bufnr: integer)",
	},
	default = function(_client, _bufnr) end,
	default_text = "function(client, bufnr) end",
	description = [[
        Callback to run when the in-process language server attaches to a buffer.

        NOTE: Ignored if |crates-config-autoload| is disabled.
    ]],
})
entry(schema_lsp, {
	name = "actions",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Whether to enable the `codeActionProvider` capability.
    ]],
})
entry(schema_lsp, {
	name = "completion",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Whether to enable the `completionProvider` capability.
    ]],
})
entry(schema_lsp, {
	name = "hover",
	type = BOOLEAN_TYPE,
	default = true,
	description = [[
        Whether to enable the `hover` capability.
    ]],
})

---@param s string
---@param ... any
local function warn(s, ...)
	vim.notify(s:format(...), vim.log.levels.WARN, { title = "npackages.nvim" })
end

---@param path string[]
---@param component string
---@return string[]
local function join_path(path, component)
	---@type string[]
	local p = {}
	for i, c in ipairs(path) do
		p[i] = c
	end
	table.insert(p, component)
	return p
end

---@param t table<string,any>
---@param path string[]
---@param value any
local function table_set_path(t, path, value)
	---@type table<string,any>
	local current = t
	for i, c in ipairs(path) do
		if i == #path then
			current[c] = value
		elseif type(current[c]) == "table" then
			---@type table<string,any>
			current = current[c]
		elseif current[c] == nil then
			current[c] = {}
			current = current[c]
		else
			break -- don't overwrite existing value
		end
	end
end

---comment
---@param path string[]
---@param schema table<string,SchemaElement>
---@param root_config table<string,any>
---@param user_config table<string,any>
local function handle_deprecated(path, schema, root_config, user_config)
	for k, v in pairs(user_config) do
		---@type SchemaElement|nil
		local elem
		if type(k) == "string" then
			elem = schema[k]
		end

		if elem then
			local p = join_path(path, k)
			local dep = elem.deprecated

			if dep then
				if dep.new_field and not dep.hard then
					table_set_path(root_config, dep.new_field, v)
				end
			elseif elem.type.config_type == "section" and type(v) == "table" then
				---@cast elem SectionSchemaElement|HiddenSectionSchemaElement
				---@cast v table<string,any>
				handle_deprecated(p, elem.fields, root_config, v)
			end
		end
	end
end

---@param schema_type SchemaType
---@return string
local function to_user_config_type_string(schema_type)
	local config_type = schema_type.config_type
	if config_type == "section" then
		return "table"
	elseif type(config_type) == "string" then
		return config_type
	else
		return table.concat(config_type, "|")
	end
end

---@param value_type type
---@param schema_type SchemaType
---@return boolean
local function matches_type(value_type, schema_type)
	local config_type = schema_type.config_type
	if type(config_type) == "string" then
		---@cast config_type ConfigType
		return value_type == config_type
	else
		---@cast schema_type ConfigType[]
		return vim.tbl_contains(config_type, value_type)
	end
end

---@param path string[]
---@param schema table<string,SchemaElement>|SchemaElement[]
---@param user_config table<string,any>
M.validate_schema = function(path, schema, user_config)
	for k, v in pairs(user_config) do
		local p = join_path(path, k)
		---@type SchemaElement|nil
		local elem
		if type(k) == "string" then
			elem = schema[k]
		end

		if elem then
			local value_type = type(v)
			local dep = elem.deprecated

			if dep then
				if dep.new_field then
					---@type string
					local dep_text
					if dep.hard then
						dep_text = "deprecated and won't work anymore"
					else
						dep_text = "deprecated and will stop working soon"
					end

					warn(
						"'%s' is now %s, please use '%s'",
						table.concat(p, "."),
						dep_text,
						table.concat(dep.new_field, ".")
					)
				else
					warn("'%s' is now deprecated, ignoring", table.concat(p, "."))
				end
			elseif elem.type.config_type == "section" then
				if value_type == "table" then
					M.validate_schema(p, elem.fields, v)
				else
					warn(
						"Config field '%s' was expected to be of type 'table' but was '%s', using default value.",
						table.concat(p, "."),
						value_type
					)
				end
			else
				if not matches_type(value_type, elem.type) then
					warn(
						"Config field '%s' was expected to be of type '%s' but was '%s', using default value.",
						table.concat(p, "."),
						to_user_config_type_string(elem.type),
						value_type
					)
				end
			end
		else
			warn("Ignoring invalid config key '%s'", table.concat(p, "."))
		end
	end
end

---@param schema table<string,SchemaElement>|SchemaElement[]
---@param user_config table<string,any>
---@return table
local function build_config(schema, user_config)
	---@type table<string,any>
	local config = {}

	for _, elem in ipairs(schema) do
		local key = elem.name
		local user_value = user_config[key]
		local value_type = type(user_value)

		if elem.type.config_type == "section" then
			if value_type == "table" then
				config[key] = build_config(elem.fields, user_value)
			else
				config[key] = build_config(elem.fields, {})
			end
		else
			if matches_type(value_type, elem.type) then
				config[key] = user_value
			else
				config[key] = elem.default
			end
		end
	end

	return config
end

---Builds config object by merging global options with runtime and default options
---@param user_config table<string,any>|nil
---@return Config
function M.build(user_config)
	user_config = vim.g.npackages or user_config or {}
	local user_config_type = type(user_config)
	if user_config_type ~= "table" then
		warn("Expected config of type 'table' found '%s'", user_config_type)
		user_config = {}
	end

	handle_deprecated({}, M.schema, user_config, user_config)
	M.validate_schema({}, M.schema, user_config)
	return build_config(M.schema, user_config)
end

return M
