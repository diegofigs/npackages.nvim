local M = {}

---@class DateTime
---@field epoch integer
local DateTime = {}
M.DateTime = DateTime

---@param epoch integer
---@return DateTime
function DateTime.new(epoch)
	return setmetatable({ epoch = epoch }, { __index = DateTime })
end

---@param str string
---@return DateTime|nil
function DateTime.parse_rfc_3339(str)
	-- lua regex suports no {n} occurences
	local pat = "^([0-9][0-9][0-9][0-9])%-([0-9][0-9])%-([0-9][0-9])" -- date
		.. "T([0-9][0-9]):([0-9][0-9]):([0-9][0-9])%.[0-9]+" -- time
		.. "([%+%-])([0-9][0-9]):([0-9][0-9])$" -- offset

	local year, month, day, hour, minute, second, offset, offset_hour, offset_minute = str:match(pat)
	if year then
		---@type integer, integer
		local h, m
		if offset == "+" then
			h = tonumber(hour) + tonumber(offset_hour)
			m = tonumber(minute) + tonumber(offset_minute)
		elseif offset == "-" then
			h = tonumber(hour) - tonumber(offset_hour)
			m = tonumber(minute) - tonumber(offset_minute)
		end
		return DateTime.new(os.time({
			---@diagnostic disable-next-line: assign-type-mismatch
			year = tonumber(year),
			---@diagnostic disable-next-line: assign-type-mismatch
			month = tonumber(month),
			---@diagnostic disable-next-line: assign-type-mismatch
			day = tonumber(day),
			hour = h,
			min = m,
			sec = tonumber(second),
		}))
	end

	return nil
end

---@param str string
---@return DateTime|nil
function DateTime.parse_iso_8601(str)
	local pattern = "(%d+)%-(%d+)%-(%d+)%a(%d+)%:(%d+)%:([%d%.]+)([Z%+%-])(%d?%d?)%:?(%d?%d?)"
	local year, month, day, hour, minute, seconds, offsetsign, offsethour, offsetmin = str:match(pattern)
	local timestamp = os.time({ year = year, month = month, day = day, hour = hour, min = minute, sec = seconds })
	local offset = 0
	if offsetsign ~= "Z" then
		offset = tonumber(offsethour) * 60 + tonumber(offsetmin)
		---@diagnostic disable-next-line: no-unknown, undefined-global
		if xoffset == "-" then
			offset = offset * -1
		end
	end

	return DateTime.new(timestamp + offset)
end

---@param format string
---@return string
function DateTime:display(format)
	---@type string
	return os.date(format, self.epoch)
end

return M
