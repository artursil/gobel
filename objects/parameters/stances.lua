--- Numeric rewards, counters, and effect priorities for stances.
--- @module objects.parameters.stances

return {
	stance_point_before_turn_points = 1,
	stance_mult_before_turn_plus_mult = 1,
	stance_heavy_point_before_turn_points = 2,
	stance_gluttony_x_mult_per_steel = 0.5,
	stance_focus_bonus_points_per_round = 5,
	stance_persistent_flux_special_delta = 3,
	stance_persistent_flux_wall_delta = -3,
	stance_persistent_flux_counter_floor = 0,

	stance_turn_bonus_priority = 20,
	stance_gluttony_priority = 15,
	stance_persistent_flux_priority = 10,
	stance_echo_priority = 5,
}
