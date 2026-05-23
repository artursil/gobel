--- Pattern detection facade (X/+, wall groups). Legacy diagonal counter deprecated.
--- @module patterns

local shape_patterns = require("game.patterns.shape_patterns")

local M = {}

M.pattern_scoring = shape_patterns.pattern_scoring
M.detect_x_patterns = shape_patterns.detect_x_patterns
M.detect_plus_patterns = shape_patterns.detect_plus_patterns
M.group_connected = shape_patterns.group_connected
M.group_has_wall_stone = shape_patterns.group_has_wall_stone
M.wall_points_for_connected_group_size = shape_patterns.wall_points_for_connected_group_size
M.x_mult_factor_for_tier = shape_patterns.x_mult_factor_for_tier
M.x_mult_factor_for_x_stone_count = shape_patterns.x_mult_factor_for_x_stone_count
M.count_x_stones_in_pattern = shape_patterns.count_x_stones_in_pattern
M.detect_newly_completed_x_patterns = shape_patterns.detect_newly_completed_x_patterns
M.plus_mult_bonus_for_tier = shape_patterns.plus_mult_bonus_for_tier
M.plus_mult_bonus_for_plus_stone_count = shape_patterns.plus_mult_bonus_for_plus_stone_count
M.count_plus_stones_in_pattern = shape_patterns.count_plus_stones_in_pattern
M.detect_newly_completed_plus_patterns = shape_patterns.detect_newly_completed_plus_patterns

--- @deprecated use ``detect_x_patterns`` and check ``has_x_stone`` per pattern
--- @param b table
--- @param color integer
--- @return integer
function M.count_x_stones_in_diagonal_patterns(b, color)
	local patterns_found = shape_patterns.detect_x_patterns(b, color)
	local sum = 0
	for i = 1, #patterns_found do
		local p = patterns_found[i]
		if p.has_x_stone then
			for j = 1, #p.cells do
				local r, c = p.cells[j][1], p.cells[j][2]
				local cell = b[r][c]
				if cell and cell.kind == "x_stone" then
					sum = sum + 1
				end
			end
		end
	end
	return sum
end

return M
