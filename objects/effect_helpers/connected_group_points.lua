--- Placement group-size point bonus helper shared by wall, diagonal_stone, and line_stone factories.
--- @module objects.effect_helpers.connected_group_points

local board = require("board")
local shape_patterns = require("game.patterns.shape_patterns")
local animations = require("objects.animations")

local M = {}

--- @param group_size integer
--- @param block_size integer
--- @param points_per_block integer
--- @return integer
function M.points_for_group_size(group_size, block_size, points_per_block)
	if group_size <= 0 or block_size <= 0 or points_per_block <= 0 then
		return 0
	end
	return math.floor(group_size / block_size) * points_per_block
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param connectivity "orthogonal"|"diagonal"
--- @return table
function M.connected_group(b, row, col, connectivity)
	if connectivity == "diagonal" then
		return shape_patterns.group_diagonal_connected(b, row, col)
	end
	return shape_patterns.group_connected(b, row, col)
end

--- @param state table
--- @param owner string
--- @param row integer|nil
--- @param col integer|nil
--- @param opts table { stone_kind: string, connectivity: "orthogonal"|"diagonal", block_size: integer, points_per_block: integer, animation?: string }
--- @return integer bonus applied
function M.apply_group_size_bonus(state, owner, row, col, opts)
	if row == nil or col == nil then
		return 0
	end
	local cell = state.board[row] and state.board[row][col]
	if not cell or board.is_empty(cell) or cell.kind ~= opts.stone_kind then
		return 0
	end
	local group = M.connected_group(state.board, row, col, opts.connectivity)
	local bonus = M.points_for_group_size(#group, opts.block_size, opts.points_per_block)
	if bonus <= 0 then
		return 0
	end
	state.scores.points[owner] = state.scores.points[owner] + bonus
	if opts.animation == "wall_stone_bounce" then
		animations.add_animation("wall_stone_bounce")(state, {
			owner = owner,
			cells = group,
			bonus = bonus,
			anchor_row = row,
			anchor_col = col,
		})
	end
	return bonus
end

return M
