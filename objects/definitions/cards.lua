--- Unified card definitions.
--- Source of truth for all card content.
--- @module objects.definitions.cards

local M = {
	card_point_tap = {
		id = "card_point_tap",
		type = "card",
		name = "Point Tap",
		description = "Gain 2 points immediately.",
		display_name = "Point Tap",
		rarity = "common",
		probability = 1.0,
		cost = 1,
		energy_cost = 1,
		effects = { { effect_name = "add_points", phase = "points", value = 2, priority = 10 } },
	},
	card_point_push = {
		id = "card_point_push",
		type = "card",
		name = "Point Push",
		description = "Gain 4 points immediately.",
		display_name = "Point Push",
		rarity = "uncommon",
		probability = 0.8,
		cost = 2,
		energy_cost = 2,
		effects = { { effect_name = "add_points", phase = "points", value = 4, priority = 10 } },
	},
	card_small_mult = {
		id = "card_small_mult",
		type = "card",
		name = "Small Mult",
		description = "Gain 1 multiplier immediately.",
		display_name = "Small Mult",
		rarity = "common",
		probability = 1.0,
		cost = 1,
		energy_cost = 1,
		effects = { { effect_name = "add_mult", phase = "mult", value = 1, priority = 10 } },
	},
	card_big_mult = {
		id = "card_big_mult",
		type = "card",
		name = "Big Mult",
		description = "Gain 2 multiplier immediately.",
		display_name = "Big Mult",
		rarity = "uncommon",
		probability = 0.8,
		cost = 2,
		energy_cost = 2,
		effects = { { effect_name = "add_mult", phase = "mult", value = 2, priority = 10 } },
	},
	card_balanced_boost = {
		id = "card_balanced_boost",
		type = "card",
		name = "Balanced Boost",
		description = "Gain 2 points and 1 multiplier.",
		display_name = "Balanced Boost",
		rarity = "rare",
		probability = 0.6,
		cost = 2,
		energy_cost = 2,
		effects = {
			{ effect_name = "add_points", phase = "points", value = 2, priority = 10 },
			{ effect_name = "add_mult", phase = "mult", value = 1, priority = 10 },
		},
	},
}

return M
