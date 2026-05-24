--- Numeric rewards, pattern thresholds, and effect priorities for stones.
--- @module objects.parameters.stones

return {
	x_pattern_tiers = { 5, 9, 13, 17, 21 },
	plus_pattern_tiers = { 5, 9, 13, 17, 21 },

	x_stone_mult_factor = 2,
	plus_stone_mult_add = 5,
	wall_stones_per_block = 5,
	wall_points_per_block = 5,
	wall_celebrate_min_group = 5,

	pattern_effect_priority = 12,
	wall_effect_priority = 14,
	default_effect_priority = 10,

	stone_power_placement_points = 2,
	stone_focus_placement_plus_mult = 1,
	stone_lieutenant_distance_bonus = 1,
	stone_tower_corner_territory_add = 1,
}
