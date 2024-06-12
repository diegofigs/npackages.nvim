--- Strips ^ and ~ from version
---@param value string - value from which to strip ^ and ~ from
---@return string | nil
return function(value)
	if value == nil then
		return nil
	end

	local version = value:gsub("%^", ""):gsub("~", "")
	return version
end
