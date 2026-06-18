--- Orthogonal wall-group block count at the last placed wall stone.
--- @module objects.effects_conditions.helpers.shared.wall_group_blocks

local board = require("board")
local shape_patterns = require("game.patterns.shape_patterns")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local stone_params = require("objects.parameters.stones")

local M = {}

--- Count full wall point blocks for the placed wall's orthogonal connected group.
function M.blocks_at_placement(state, _owner)
	local row, col = helpers.placement_coords(state)
	if not row or not col then
		return 0
	end
	local cell = state.board[row] and state.board[row][col]
	if not cell or board.is_empty(cell) or cell.kind ~= "wall" then
		return 0
	end
	local group = shape_patterns.group_connected(state.board, row, col)
	local group_size = #group
	local block_size = stone_params.wall_stones_per_block
	if group_size <= 0 or block_size <= 0 then
		return 0
	end
	return math.floor(group_size / block_size)
end

return M
