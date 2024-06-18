---@class State
---@field cfg Config
---@field visible boolean
-- npm metadata
---@field has_old_yarn boolean
---@field package_manager table<integer,string>
local State = {
	--- npm related
	--- If true the project is using yarn 2<
	has_old_yarn = false,
	package_manager = {},
}

return State
