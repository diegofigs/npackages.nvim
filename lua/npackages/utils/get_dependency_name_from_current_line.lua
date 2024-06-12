local get_dependency_name_from_line = require("npackages.utils.get_dependency_name_from_line")

--- Gets dependency name from current line
---@return string?
return function()
	local current_line = vim.fn.getline(".")

	local dependency_name = get_dependency_name_from_line(current_line)

	if dependency_name then
		return dependency_name
	else
		return nil
	end
end
