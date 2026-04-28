--- Live score: territory points × overall multiplier; X-kind stones inside diagonal crosses add to mult.

local board = require("board")
local config = require("config")
local patterns = require("patterns")
local stone_kinds = require("stone_kinds")
local territory_resolver = require("resolver.territory")

local M = {}

local BASE_MULT = 1

function M.territory_map(b, territory_mode)
	return territory_resolver.compute_from_board(b, territory_mode or "regional")
end

function M.territory_points(territory, color)
	local n = config.BOARD_SIZE
	local count = 0
	for r = 1, n do
		for c = 1, n do
			if territory[r][c] == color then
				count = count + 1
			end
		end
	end
	return count
end

--- Territory-backed points for compatibility with existing call sites.
--- @param b table
--- @param color integer
--- @param territory_mode string|nil
--- @return integer
function M.liberty_points(b, color, territory_mode)
	local territory = M.territory_map(b, territory_mode)
	return M.territory_points(territory, color)
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
