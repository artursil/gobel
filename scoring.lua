--- Live score: liberty points × overall multiplier; X-kind stones inside diagonal crosses add to mult.

local patterns = require("patterns")
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

--- Sum of (X-kind hits across all complete crosses, counting overlaps) × bonus constant, added to base mult.
--- @param b table
--- @param color integer
--- @return integer
function M.mult_bonus_from_patterns(b, color)
	local nx = patterns.count_x_stones_in_diagonal_patterns(b, color)
	return nx * stone_kinds.MULT_BONUS_PER_DIAGONAL_X_PATTERN
end

--- Overall multiplier: base plus pattern-linked X stone bonus.
--- @param b table
--- @param color integer
--- @return integer
function M.overall_mult(b, color)
	return BASE_MULT + M.mult_bonus_from_patterns(b, color)
end

--- Total score used in the UI and for comparisons.
--- @param b table
--- @param color integer
--- @return integer
function M.total_score(b, color)
	return M.liberty_points(b, color) * M.overall_mult(b, color)
end

return M
