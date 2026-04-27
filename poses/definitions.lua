local M = {
	pose_point_stance = {
		id = "pose_point_stance",
		display_name = "Point Stance",
		trigger = "TURN_START",
		effect = { type = "ADD_POINTS", value = 1 },
	},
	pose_mult_stance = {
		id = "pose_mult_stance",
		display_name = "Mult Stance",
		trigger = "TURN_START",
		effect = { type = "ADD_MULT", value = 1 },
	},
	pose_heavy_point_stance = {
		id = "pose_heavy_point_stance",
		display_name = "Heavy Point Stance",
		trigger = "TURN_START",
		effect = { type = "ADD_POINTS", value = 2 },
	},
}

return M
