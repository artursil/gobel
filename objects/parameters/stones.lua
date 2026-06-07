--- Numeric rewards, pattern thresholds, and effect priorities for stones.
--- Visual specs read these via ``spec.parameters_helper`` (`P.stone.*`).
--- @module objects.parameters.stones

return {
	default_solidity = 4,
	solidity_frame_count = 4,

	x_pattern_tiers = { 5, 9, 13, 17, 21 },
	plus_pattern_tiers = { 5, 9, 13, 17, 21 },

	x_stone_mult_factor = 1.5,
	plus_stone_mult_add = 4,
	wall_stones_per_block = 5,
	wall_points_per_block = 5,
	wall_celebrate_min_group = 5,

	pattern_effect_priority = 12,
	wall_effect_priority = 14,
	default_effect_priority = 10,

	stone_power_placement_points = 2,
	stone_focus_placement_plus_mult = 1,
	stone_influence_distance_bonus = 1,
	stone_tower_corner_territory_add = 1,

	stone_basic_placement_points = 0,
	stone_basic_placement_plus_mult = 0,
	stone_basic_placement_x_mult_factor = 1,

	points_stone_t1 = 2,
	points_stone_t2 = 4,
	points_stone_t3 = 7,

	influence_t1 = 1,
	influence_t2 = 2,
	influence_t3 = 3,

	energy_stone_gain = 2,

	enclosure_stone_multiplier = 2,
	money_field_payout = 3,

	copper_threshold = 3,
	copper_threshold_plus_mult_bonus = 2,
	copper_base_points = 0,

	blockade_duration_rounds = 2,
	anti_capture_duration_rounds = 2,
	defence_solidity_bonus = 1,
	mult_control_streak_multiplier = 2,

	points_delay_rounds = 7,
	points_delay_payout = 20,

	self_destruct_immediate_points = 8,
	self_destruct_delay_rounds = 2,

	final_blow_points = 30,
	final_blow_plus_mult = 10,
	final_blow_nonfinal_points = 1,

	unlimited_upgrades_points_per_level = 1,
	unlimited_upgrades_plus_mult_per_level = 1,

	tax_money_per_enemy = 1,
	tax_points_per_enemy = 1,

	t2p_divisor = 4,
	t2p_cap = 12,
	t2m_divisor = 6,
	t2m_cap = 8,

	ems_round_money = 1,
	ems_capture_multiplier = 2,

	eps_round_points = 3,
	eps_capture_multiplier = 2,

	hpml_points_gain = 12,
	hpml_plus_mult_gain = 6,
	hpml_money_loss = 8,

	retrigger_fallback_points = 1,

	diagonal_stone_block_size = 5,
	diagonal_stone_points_per_block = 5,
	line_stone_block_size = 5,
	line_stone_points_per_block = 5,

	kamikaze_points_bonus = 15,
	kamikaze_self_removal_counts_as_prisoner = false,

	capture_bonus_points_per_stone = 3,
}
