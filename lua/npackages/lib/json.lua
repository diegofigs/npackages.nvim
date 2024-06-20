local json = {}
---@class vim.json.DecodeOpts
---@class DecodeOpts
---@field luanil Luanil

---@class Luanil
---@field object boolean
---@field array boolean

---@type vim.json.DecodeOpts
local JSON_DECODE_OPTS = { luanil = { object = true, array = true } }

---@param json_str string
---@return table|nil
function json.decode(json_str)
	local decoded = vim.json.decode(json_str, JSON_DECODE_OPTS)
	if decoded and type(decoded) == "table" then
		return decoded
	end
end

return json
