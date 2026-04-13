--- Live score: liberty points × overall multiplier; X stones add to mult (not to per-liberty weight).

local cells = require("board")
local config = require("config")
local rules = require("rules")
local stone_kinds = require("stone_kinds")

local M = {}

local BASE_MULT = 1

--- Counts unique empty intersections orthogonally adjacent to any stone of the color (weight 1 each).
--- @param b table
--- @param color integer
--- @return integer
function M.liberty_points(b, color)
	return rules.unique_liberty_points(b, color)
end

--- Sums multiplier bonuses from on-board stones of this color (e.g. +3 per X).
--- @param b table
--- @param color integer
--- @return integer
function M.mult_bonus_from_stones(b, color)
	local n = config.BOARD_SIZE
	local sum = 0
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not cells.is_empty(cell) and cell.color == color then
				sum = sum + stone_kinds.overall_mult_bonus_for_kind(cell.kind)
			end
		end
	end
	return sum
end

--- Overall multiplier: base plus bonuses from all stones of that color on the board.
--- @param b table
--- @param color integer
--- @return integer
function M.overall_mult(b, color)
	return BASE_MULT + M.mult_bonus_from_stones(b, color)
end

--- Total score used in the UI and for comparisons.
--- @param b table
--- @param color integer
--- @return integer
function M.total_score(b, color)
	return M.liberty_points(b, color) * M.overall_mult(b, color)
end

return M
