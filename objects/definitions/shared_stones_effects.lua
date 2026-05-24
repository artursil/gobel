--- Reusable stone effect definition tables (pattern + wall placement).
--- @module objects.definitions.shared_stones_effects

local stone_params = require("objects.parameters.stones")

local M = {}

M.pattern_x_mult = {
	effect_name = "pattern_x_mult",
	macro = "playing_stones",
	sub = "mult",
	priority = stone_params.pattern_effect_priority,
}

M.pattern_plus_mult = {
	effect_name = "pattern_plus_mult",
	macro = "playing_stones",
	sub = "mult",
	priority = stone_params.pattern_effect_priority,
}

M.wall_stone = {
	effect_name = "wall_stone",
	macro = "playing_stones",
	sub = "points",
	priority = stone_params.wall_effect_priority,
}

M.all_stone_board_effects = {
	M.pattern_x_mult,
	M.pattern_plus_mult,
}

return M
