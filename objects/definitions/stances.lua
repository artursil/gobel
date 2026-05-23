--- Unified stance definitions (gameplay + **visual**).
--- @module objects.definitions.stances

local FRAME = "sprites/stances/frame_1_r.png"

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
		visual = { graphic = "sprites/cards/background_1_r.png", frame = FRAME },
		effects = {
			{ effect_name = "add_points", macro = "before_turn", sub = "points", value = 1, priority = 20 },
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
		visual = { graphic = "sprites/cards/background_1_r.png", frame = FRAME },
		effects = {
			{ effect_name = "add_mult", macro = "before_turn", sub = "mult", value = 1, priority = 20 },
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
		visual = { graphic = "sprites/cards/background_1_r.png", frame = FRAME },
		effects = {
			{ effect_name = "add_points", macro = "before_turn", sub = "points", value = 2, priority = 20 },
		},
	},
	stance_gluttony = {
		id = "stance_gluttony",
		type = "stance",
		name = "Gluttony",
		display_name = "Gluttony",
		description = "When a special stone is placed, multiply ×Mult by 1.5 for each steel card in hand.",
		rarity = "rare",
		probability = 0.6,
		cost = 0,
		visual = { graphic = "sprites/stances/gluttony_r.png", frame = FRAME },
		effects = {
			{
				effect_name = "count_and_multiply_x_mult",
				macro = "playing_stones",
				sub = "mult",
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
		visual = { graphic = "sprites/cards/background_1_r.png", frame = FRAME },
		effects = {
			{
				effect_name = "add_points",
				macro = "playing_stones",
				sub = "points",
				value = 5,
				priority = 20,
				conditions = {
					{ condition_name = "temporary_stance_active" },
					{ condition_name = "stance_owner_is_current_turn" },
				},
			},
		},
	},
	stance_echo = {
		id = "stance_echo",
		type = "stance",
		name = "Echo",
		display_name = "Echo",
		description = "Copies effects from the first non-echo stance to the right.",
		rarity = "rare",
		probability = 0.4,
		cost = 0,
		visual = { graphic = "sprites/stances/echo_r.png", frame = FRAME },
		effects = {
			{
				effect_name = "copy_right_effect",
				macro = "playing_stones",
				sub = "territory",
				territory_step = "distance",
				priority = 5,
			},
			{
				effect_name = "copy_right_effect",
				macro = "playing_stones",
				sub = "territory",
				territory_step = "value",
				priority = 5,
			},
			{ effect_name = "copy_right_effect", macro = "playing_stones", sub = "points", priority = 5 },
			{ effect_name = "copy_right_effect", macro = "playing_stones", sub = "mult", priority = 5 },
		},
	},
	stance_persistent_flux = {
		id = "stance_persistent_flux",
		type = "stance",
		name = "Persistent Flux",
		display_name = "Persistent Flux",
		description = "Run-persistent mult: +3 on special stone, -3 on wall stone.",
		description_status = {
			kind = "run_counter",
			counter_key = "persistent_flux_mult",
			label = "Currently",
			signed = true,
		},
		rarity = "rare",
		probability = 0.4,
		cost = 0,
		visual = { graphic = "sprites/cards/background_test2_r.png", frame = FRAME },
		effects = {
			{
				effect_name = "adjust_run_persistent_counter",
				macro = "playing_stones",
				sub = "mult",
				value = { counter_key = "persistent_flux_mult", delta = 3 },
				priority = 10,
				conditions = {
					{ condition_name = "stone_tag_just_added", tag = "special" },
				},
			},
			{
				effect_name = "adjust_run_persistent_counter",
				macro = "playing_stones",
				sub = "mult",
				value = { counter_key = "persistent_flux_mult", delta = -3 },
				priority = 10,
				conditions = {
					{ condition_name = "stone_tag_just_added", tag = "wall" },
				},
			},
			{
				effect_name = "apply_run_persistent_counter_as_mult",
				macro = "playing_stones",
				sub = "mult",
				value = { counter_key = "persistent_flux_mult" },
				priority = 20,
				conditions = {
					{ condition_name = "round_number_exactly", value = 1 },
				},
			},
			{
				effect_name = "apply_run_persistent_pending_delta_as_mult",
				macro = "playing_stones",
				sub = "mult",
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
