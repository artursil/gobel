local M = {
	pose_point_stance = {
		id = "pose_point_stance",
		display_name = "Point Stance",
		trigger = "TURN_START",
		effects = {
			{ effect_name = "add_points", phase = "points", value = 1, priority = 20 },
		},
	},
	pose_mult_stance = {
		id = "pose_mult_stance",
		display_name = "Mult Stance",
		trigger = "TURN_START",
		effects = {
			{ effect_name = "add_mult", phase = "mult", value = 1, priority = 20 },
		},
	},
	pose_heavy_point_stance = {
		id = "pose_heavy_point_stance",
		display_name = "Heavy Point Stance",
		trigger = "TURN_START",
		effects = {
			{ effect_name = "add_points", phase = "points", value = 2, priority = 20 },
		},
	},
}

return M
