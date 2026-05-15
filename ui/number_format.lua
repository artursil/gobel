--- HUD number formatting: plain integers/decimals below 1e9, scientific notation at and above.
--- @module ui.number_format

local M = {}

M.SCIENTIFIC_THRESHOLD = 1e9

--- @param n number
--- @return boolean
local function uses_scientific(n)
	return math.abs(n or 0) >= M.SCIENTIFIC_THRESHOLD
end

--- Whole numbers for territory, points, +Mult, totals (input is ceiled by callers when needed).
--- @param n number
--- @return string
function M.format_integer(n)
	local v = math.ceil(n or 0)
	if uses_scientific(v) then
		return string.format("%.2e", v)
	end
	return string.format("%d", v)
end

--- Fixed decimal places for turn bonus, ×Mult, combined mult, etc.
--- @param n number
--- @param places integer
--- @return string
function M.format_decimal(n, places)
	places = places or 1
	local v = n or 0
	if uses_scientific(v) then
		return string.format("%." .. places .. "e", v)
	end
	return string.format("%." .. places .. "f", v)
end

return M
