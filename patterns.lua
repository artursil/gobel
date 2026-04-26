--- Detects diagonal cross “X patterns” and counts X-kind stones that sit on those intersections.

local cells = require("board")
local config = require("config")
local stone_kinds = require("stone_kinds")

local M = {}

local DIAG_OFFSETS = {
	{ 0, 0 },
	{ -1, -1 },
	{ -1, 1 },
	{ 1, -1 },
	{ 1, 1 },
}

--- True when all five diagonal cross cells are occupied by this chain color (any stone kind).
--- @param b table
--- @param cr integer center row
--- @param cc integer center column
--- @param color integer chain color
--- @return boolean
local function diagonal_cross_filled(b, cr, cc, color)
	for i = 1, #DIAG_OFFSETS do
		local dr, dc = DIAG_OFFSETS[i][1], DIAG_OFFSETS[i][2]
		local r, c = cr + dr, cc + dc
		local cell = b[r][c]
		if cells.is_empty(cell) or cell.color ~= color then
			return false
		end
	end
	return true
end

--- Sums, over every complete diagonal cross, how many X-kind stones appear in that cross.
--- The same physical stone contributes once per pattern it belongs to (overlapping patterns stack).
--- @param b table
--- @param color integer
--- @return integer
function M.count_x_stones_in_diagonal_patterns(b, color)
	local n = config.BOARD_SIZE
	if n < 3 then
		return 0
	end
	local sum = 0
	for cr = 2, n - 1 do
		for cc = 2, n - 1 do
			if diagonal_cross_filled(b, cr, cc, color) then
				for i = 1, #DIAG_OFFSETS do
					local dr, dc = DIAG_OFFSETS[i][1], DIAG_OFFSETS[i][2]
					local r, c = cr + dr, cc + dc
					local cell = b[r][c]
					if not cells.is_empty(cell) and cell.color == color and cell.kind == stone_kinds.X then
						sum = sum + 1
					end
				end
			end
		end
	end
	return sum
end

return M
