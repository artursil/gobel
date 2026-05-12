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
	stance_blueprint = {
		id = "stance_blueprint",
		type = "stance",
		name = "Blueprint",
		display_name = "Blueprint",
		description = "Copies effects from the first non-blueprint stance to the right.",
		rarity = "rare",
		probability = 0.4,
		cost = 0,
		effects = {
			{ effect_name = "copy_right_effect", phase = "distance", priority = 5 },
			{ effect_name = "copy_right_effect", phase = "territory", priority = 5 },
			{ effect_name = "copy_right_effect", phase = "points", priority = 5 },
			{ effect_name = "copy_right_effect", phase = "mult", priority = 5 },
		},
	},
	stance_persistent_flux = {
		id = "stance_persistent_flux",
		type = "stance",
		name = "Persistent Flux",
		display_name = "Persistent Flux",
		description = "Run-persistent mult: +3 on special stone, -3 on wall stone.",
		rarity = "rare",
		probability = 0.4,
		cost = 0,
		effects = {
			{
				effect_name = "adjust_run_persistent_counter",
				phase = "mult",
				value = { counter_key = "persistent_flux_mult", delta = 3 },
				priority = 10,
				conditions = {
					{ condition_name = "stone_tag_just_added", tag = "special" },
				},
			},
			{
				effect_name = "adjust_run_persistent_counter",
				phase = "mult",
				value = { counter_key = "persistent_flux_mult", delta = -3 },
				priority = 10,
				conditions = {
					{ condition_name = "stone_tag_just_added", tag = "wall" },
				},
			},
			{
				effect_name = "apply_run_persistent_counter_as_mult",
				phase = "mult",
				value = { counter_key = "persistent_flux_mult" },
				priority = 20,
				conditions = {
					{ condition_name = "round_number_exactly", value = 1 },
				},
			},
			{
				effect_name = "apply_run_persistent_pending_delta_as_mult",
				phase = "mult",
				value = { counter_key = "persistent_flux_mult" },
				priority = 20,
				conditions = {
					{ condition_name = "round_number_at_least", value = 2 },
				},
			},
		},
	},
}

return M
