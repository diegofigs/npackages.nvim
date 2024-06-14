local M = {}

---@enum Cond
M.Cond = {
	EQ = 1,
	LT = 2,
	LE = 3,
	GT = 4,
	GE = 5,
	CR = 6,
	TL = 7,
	WL = 8,
	BL = 9,
}

---@class SemVer
---@field major integer|nil
---@field minor integer|nil
---@field patch integer|nil
---@field pre string|nil
---@field meta string|nil
local SemVer = {}
M.SemVer = SemVer

---@param obj SemVer
---@return SemVer
function SemVer.new(obj)
	return setmetatable(obj, { __index = SemVer })
end

---@return string
function SemVer:display()
	local text = ""
	if self.major then
		text = text .. self.major
	end

	if self.minor then
		text = text .. "." .. self.minor
	end

	if self.patch then
		text = text .. "." .. self.patch
	end

	if self.pre then
		text = text .. "-" .. self.pre
	end

	if self.meta then
		text = text .. "+" .. self.meta
	end

	return text
end

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

---@class WorkingCrate
---@field name string
---@field line integer
---@field col Span
---@field kind WorkingCrateKind

---@enum WorkingCrateKind
M.WorkingCrateKind = {
	INLINE = 1,
	TABLE = 2,
}

return M
