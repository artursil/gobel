--- Unified stance definitions.
--- Source of truth for all stance content.
--- @module objects.definitions.stances

local M = {
	stance_point = {
		id = "stance_point",
		display_name = "Point Stance",
		trigger = "TURN_START",
		effects = {
			{ effect_name = "add_points", phase = "points", value = 1, priority = 20 },
		},
	},
	stance_mult = {
		id = "stance_mult",
		display_name = "Mult Stance",
		trigger = "TURN_START",
		effects = {
			{ effect_name = "add_mult", phase = "mult", value = 1, priority = 20 },
		},
	},
	stance_heavy_point = {
		id = "stance_heavy_point",
		display_name = "Heavy Point Stance",
		trigger = "TURN_START",
		effects = {
			{ effect_name = "add_points", phase = "points", value = 2, priority = 20 },
		},
	},
}

return M
