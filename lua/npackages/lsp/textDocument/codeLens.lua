local state = require("npackages.lsp.state")
local scanner = require("npackages.lsp.scanner")

local M = {}

---@param params lsp.CodeLensParams
---@return lsp.CodeLens[]
function M.get(params)
	local doc = state.documents[params.textDocument.uri]
	if doc == nil then
		return {}
	end

	local lines = vim.split(doc.text, "\n")
	if not lines then
		return {}
	end

	local _, _, scripts = scanner.scan_package_doc(lines)
	local code_lenses = {}

	for _, script in pairs(scripts) do
		table.insert(code_lenses, {
			range = script.range,
			command = {
				title = "Run",
				command = "run_script",
				arguments = { script.name, params.textDocument.uri },
			},
		})
	end

	return code_lenses
end

return M
