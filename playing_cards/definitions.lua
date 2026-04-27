local M = {
	card_point_tap = {
		id = "card_point_tap",
		name = "Point Tap",
		description = "Gain 2 points immediately.",
		display_name = "Point Tap",
		energy_cost = 1,
		effects = { { type = "ADD_POINTS", value = 2 } },
	},
	card_point_push = {
		id = "card_point_push",
		name = "Point Push",
		description = "Gain 4 points immediately.",
		display_name = "Point Push",
		energy_cost = 2,
		effects = { { type = "ADD_POINTS", value = 4 } },
	},
	card_small_mult = {
		id = "card_small_mult",
		name = "Small Mult",
		description = "Gain 1 multiplier immediately.",
		display_name = "Small Mult",
		energy_cost = 1,
		effects = { { type = "ADD_MULT", value = 1 } },
	},
	card_big_mult = {
		id = "card_big_mult",
		name = "Big Mult",
		description = "Gain 2 multiplier immediately.",
		display_name = "Big Mult",
		energy_cost = 2,
		effects = { { type = "ADD_MULT", value = 2 } },
	},
	card_balanced_boost = {
		id = "card_balanced_boost",
		name = "Balanced Boost",
		description = "Gain 2 points and 1 multiplier.",
		display_name = "Balanced Boost",
		energy_cost = 2,
		effects = {
			{ type = "ADD_POINTS", value = 2 },
			{ type = "ADD_MULT", value = 1 },
		},
	},
}

return M
