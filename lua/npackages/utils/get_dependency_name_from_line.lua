local clean_version = require("npackages.utils.clean_version")

--- Checks if the given string conforms to 1.0.0 version format
-- @param value: string - value to check if conforms
-- @return boolean
local is_valid_dependency_version = function(value)
	local cleaned_version = clean_version(value)

	if cleaned_version == nil then
		return false
	end

	local position = 0
	local is_valid = true

	-- Check that the first two chunks in version string are numbers
	-- Everything beyond could be unstable version suffix
	for chunk in string.gmatch(cleaned_version, "([^.]+)") do
		if position ~= 2 and type(tonumber(chunk)) ~= "number" then
			is_valid = false
		end

		position = position + 1
	end

	return is_valid
end

--- Gets the dependency name from the given buffer line
---@param line string - buffer line from which to get the name from
---@return string?
return function(line)
	local value = {}

	-- Tries to extract name and version
	for chunk in string.gmatch(line, [["(.-)"]]) do
		table.insert(value, chunk)
	end

	-- If no version or name fail
	if not value[1] or not value[2] then
		return nil
	end

	local is_valid_version = is_valid_dependency_version(value[2])

	-- if is_installed and is_valid_version then
	if is_valid_version then
		return value[1]
	end

	return nil
end
