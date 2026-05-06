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
	stance_special_steel_sync = {
		id = "stance_special_steel_sync",
		type = "stance",
		name = "Special Steel Sync",
		display_name = "Special Steel Sync",
		description = "When a special stone is placed, multiply ×Mult by 1.5 for each steel card in hand.",
		rarity = "rare",
		probability = 0.6,
		cost = 0,
		effects = {
			{
				effect_name = "count_and_multiply_x_mult",
				phase = "mult",
				value = 0.5,
				priority = 15,
				conditions = {
					{ condition_name = "stone_tag_just_added", tag = "special" },
				},
			},
		},
	},
	stance_focus_bonus = {
		id = "stance_focus_bonus",
		type = "stance",
		name = "Focus Bonus",
		display_name = "Focus Bonus",
		description = "Temporary stance: +5 points per round.",
		rarity = "rare",
		probability = 0,
		cost = 0,
		effects = {
			{
				effect_name = "add_points",
				phase = "points",
				value = 5,
				priority = 20,
				conditions = {
					{ condition_name = "temporary_stance_active" },
					{ condition_name = "stance_owner_is_current_turn" },
				},
			},
		},
	},
}

return M
