--- Unified stance definitions (gameplay + **visual**).
--- @module objects.definitions.stances

local FRAME = "sprites/stances/frame_1_r.png"
local S = require("objects.parameters.stances")

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
			{
				effect_name = "add_points",
				action = "before_turn",
				phase = "points",
				value = S.stance_point_before_turn_points,
				priority = S.stance_turn_bonus_priority,
			},
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
			{
				effect_name = "add_mult",
				action = "before_turn",
				phase = "mult",
				value = S.stance_mult_before_turn_plus_mult,
				priority = S.stance_turn_bonus_priority,
			},
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
			{
				effect_name = "add_points",
				action = "before_turn",
				phase = "points",
				value = S.stance_heavy_point_before_turn_points,
				priority = S.stance_turn_bonus_priority,
			},
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
				action = "on_play",
				phase = "mult",
				value = S.stance_gluttony_x_mult_per_steel,
				priority = S.stance_gluttony_priority,
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
				action = "on_play",
				phase = "points",
				value = S.stance_focus_bonus_points_per_round,
				priority = S.stance_turn_bonus_priority,
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
				action = "on_play",
				phase = "territory",
				territory_step = "distance",
				priority = S.stance_echo_priority,
			},
			{
				effect_name = "copy_right_effect",
				action = "on_play",
				phase = "territory",
				territory_step = "value",
				priority = S.stance_echo_priority,
			},
			{ effect_name = "copy_right_effect", action = "on_play", phase = "points", priority = S.stance_echo_priority },
			{ effect_name = "copy_right_effect", action = "on_play", phase = "mult", priority = S.stance_echo_priority },
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
				action = "on_play",
				phase = "mult",
				value = { counter_key = "persistent_flux_mult", delta = S.stance_persistent_flux_special_delta },
				priority = S.stance_persistent_flux_priority,
				conditions = {
					{ condition_name = "stone_tag_just_added", tag = "special" },
				},
			},
			{
				effect_name = "adjust_run_persistent_counter",
				action = "on_play",
				phase = "mult",
				value = { counter_key = "persistent_flux_mult", delta = S.stance_persistent_flux_wall_delta },
				priority = S.stance_persistent_flux_priority,
				conditions = {
					{ condition_name = "stone_tag_just_added", tag = "wall" },
				},
			},
			{
				effect_name = "apply_run_persistent_counter_as_mult",
				action = "on_play",
				phase = "mult",
				value = { counter_key = "persistent_flux_mult" },
				priority = S.stance_turn_bonus_priority,
				conditions = {
					{ condition_name = "round_number_exactly", value = 1 },
				},
			},
			{
				effect_name = "apply_run_persistent_pending_delta_as_mult",
				action = "on_play",
				phase = "mult",
				value = { counter_key = "persistent_flux_mult" },
				priority = S.stance_turn_bonus_priority,
				conditions = {
					{ condition_name = "round_number_at_least", value = 2 },
				},
			},
		},
	},
}

return M
