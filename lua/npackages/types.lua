local M = {}

---@class Span
---@field s integer -- 0-indexed inclusive
---@field e integer -- 0-indexed exclusive
local Span = {}
M.Span = Span

---@param s integer
---@param e integer
---@return Span
function Span.new(s, e)
	return setmetatable({ s = s, e = e }, { __index = Span })
end

---@param p integer
---@return Span
function Span.pos(p)
	return Span.new(p, p + 1)
end

---@return Span
function Span.empty()
	return Span.new(0, 0)
end

---@param pos integer
---@return boolean
function Span:contains(pos)
	return self.s <= pos and pos < self.e
end

---Create a new span with moved start and end bounds
---@param s integer
---@param e integer
---@return Span
function Span:moved(s, e)
	return Span.new(self.s + s, self.e + e)
end

---@return fun(): integer|nil
function Span:iter()
	local i = self.s
	local e = self.e
	return function()
		if i >= e then
			return nil
		end

		local val = i
		i = i + 1
		return val
	end
end

--- Converts it into the expected format for LSP completion items
---@param line integer
---@return lsp.Range
function Span:range(line)
	return {
		start = {
			line = line,
			character = self.s,
		},
		["end"] = {
			line = line,
			character = self.e,
		},
	}
end

return M
