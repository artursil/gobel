--- Connected-group placement point bonuses (wall, diagonal, line stones).
--- @module objects.helper_effects.connected_group_placement

local connected_group_points = require("objects.effect_helpers.connected_group_points")
local helpers = require("objects.effects_helpers")
local stone_params = require("objects.parameters.stones")

local M = {}

--- @param state table
--- @param owner string
--- @param row integer|nil
--- @param col integer|nil
--- @param opts table { stone_kind: string, connectivity: "orthogonal"|"diagonal", block_size: integer, points_per_block: integer, animation?: string }
--- @return nil
function M.apply(state, owner, row, col, opts)
	if row == nil or col == nil then
		row, col = helpers.placement_coords(state)
	end
	connected_group_points.apply_group_size_bonus(state, owner, row, col, opts)
end

--- @param state table
--- @param owner string
--- @return nil
function M.apply_wall(state, owner)
	M.apply(state, owner, nil, nil, {
		stone_kind = "wall",
		connectivity = "orthogonal",
		block_size = stone_params.wall_stones_per_block,
		points_per_block = stone_params.wall_points_per_block,
		animation = "wall_stone_bounce",
	})
end

--- @param state table
--- @param owner string
--- @return nil
function M.apply_diagonal(state, owner)
	M.apply(state, owner, nil, nil, {
		stone_kind = "diagonal_stone",
		connectivity = "diagonal",
		block_size = stone_params.diagonal_stone_block_size,
		points_per_block = stone_params.diagonal_stone_points_per_block,
	})
end

--- @param state table
--- @param owner string
--- @param stone_kind string|nil
--- @return nil
function M.apply_line(state, owner, stone_kind)
	M.apply(state, owner, nil, nil, {
		stone_kind = stone_kind or "line_stone",
		connectivity = "orthogonal",
		block_size = stone_params.line_stone_block_size,
		points_per_block = stone_params.line_stone_points_per_block,
	})
end

return M
