--- Reusable stone effect definition tables (pattern + wall placement).
--- @module objects.definitions.shared_stones_effects

local M = {}

M.pattern_x_mult = {
	effect_name = "pattern_x_mult",
	macro = "playing_stones",
	sub = "mult",
	priority = 12,
}

M.pattern_plus_mult = {
	effect_name = "pattern_plus_mult",
	macro = "playing_stones",
	sub = "mult",
	priority = 12,
}

M.wall_stone_other = {
	effect_name = "wall_stone_other",
	macro = "playing_stones",
	sub = "points",
	value = 2,
	priority = 14,
}

M.wall_stone = {
	effect_name = "wall_stone",
	macro = "playing_stones",
	sub = "points",
	value = 2,
	priority = 14,
}

M.all_stone_board_effects = {
	M.pattern_x_mult,
	M.pattern_plus_mult,
	M.wall_stone_other,
}

return M
