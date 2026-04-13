--- Detects board constructs used for scoring: diagonal cross of five same-color stones with at least one X-kind stone.

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

--- True when the five diagonal cross cells are filled with this color and at least one is an X-kind stone.
--- @param b table
--- @param cr integer center row
--- @param cc integer center column
--- @param color integer chain color
--- @return boolean
local function diagonal_x_complete_at(b, cr, cc, color)
	local has_x_kind = false
	for i = 1, #DIAG_OFFSETS do
		local dr, dc = DIAG_OFFSETS[i][1], DIAG_OFFSETS[i][2]
		local r, c = cr + dr, cc + dc
		local cell = b[r][c]
		if cells.is_empty(cell) then
			return false
		end
		if cell.color ~= color then
			return false
		end
		if cell.kind == stone_kinds.X then
			has_x_kind = true
		end
	end
	return has_x_kind
end

--- Counts distinct centers where the minimal 5-stone diagonal cross exists for this color with at least one X-kind stone.
--- @param b table
--- @param color integer
--- @return integer
function M.count_diagonal_x_patterns(b, color)
	local n = config.BOARD_SIZE
	if n < 3 then
		return 0
	end
	local count = 0
	for cr = 2, n - 1 do
		for cc = 2, n - 1 do
			if diagonal_x_complete_at(b, cr, cc, color) then
				count = count + 1
			end
		end
	end
	return count
end

return M
