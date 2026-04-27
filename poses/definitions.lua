local M = {
	pose_point_stance = {
		id = "pose_point_stance",
		display_name = "Point Stance",
		trigger = "TURN_START",
		effect_name = "add_points",
		effect_value = 1,
		effect_priority = 20,
	},
	pose_mult_stance = {
		id = "pose_mult_stance",
		display_name = "Mult Stance",
		trigger = "TURN_START",
		effect_name = "add_mult",
		effect_value = 1,
		effect_priority = 20,
	},
	pose_heavy_point_stance = {
		id = "pose_heavy_point_stance",
		display_name = "Heavy Point Stance",
		trigger = "TURN_START",
		effect_name = "add_points",
		effect_value = 2,
		effect_priority = 20,
	},
}

return M
