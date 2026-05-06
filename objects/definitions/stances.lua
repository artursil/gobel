--- Unified stance definitions.
--- Source of truth for all stance content.
--- @module objects.definitions.stances

local M = {
	stance_point = {
		id = "stance_point",
		type = "stance",
		name = "Point Stance",
		display_name = "Point Stance",
		description = "Gain 1 point at the start of each turn.",
		rarity = "common",
		probability = 1.0,
		cost = 0,
		effects = {
			{ effect_name = "add_points", phase = "points", value = 1, priority = 20 },
		},
	},
	stance_mult = {
		id = "stance_mult",
		type = "stance",
		name = "Mult Stance",
		display_name = "Mult Stance",
		description = "Gain 1 multiplier at the start of each turn.",
		rarity = "common",
		probability = 1.0,
		cost = 0,
		effects = {
			{ effect_name = "add_mult", phase = "mult", value = 1, priority = 20 },
		},
	},
	stance_heavy_point = {
		id = "stance_heavy_point",
		type = "stance",
		name = "Heavy Point Stance",
		display_name = "Heavy Point Stance",
		description = "Gain 2 points at the start of each turn.",
		rarity = "uncommon",
		probability = 0.8,
		cost = 0,
		effects = {
			{ effect_name = "add_points", phase = "points", value = 2, priority = 20 },
		},
	},
}

return M
