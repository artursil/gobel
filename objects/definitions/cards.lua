--- Unified card definitions (gameplay + **visual**).
---
--- **Visual schema** (``card.visual``; defaults merged in ``ui.card_visual``):
--- - ``background``: PNG behind the face.
--- - ``graphic``: PNG art on the face (required per card type; default path if omitted).
--- - ``border_color``: ``#RRGGBB`` thin border around the background.
--- - ``title_box_color``: fill for the title strip (default white).
--- - ``description_box_color``: fill for the description panel (default ``#E6CDA4``).
--- - ``circle_color``: ``#B43321`` for card chrome circles when drawn.
---
--- **Graphics-first checklist** for a new card: set ``id``, gameplay fields, then ``visual.graphic`` (and optional overrides).
--- @module objects.definitions.cards

local C = require("objects.parameters.cards")

local function V(overrides)
	local v = {
		background = "sprites/cards/background_1_r.png",
		graphic = "sprites/cards/graphic_default.png",
		border_color = "#E6CDA4",
		title_box_color = "#FFFFFF",
		description_box_color = "#E6CDA4",
		circle_color = "#B43321",
	}
	if overrides then
		for k, val in pairs(overrides) do
			v[k] = val
		end
	end
	return v
end

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
		visual = V(),
		effects = {
			{
				effect_name = "add_points",
				macro = "playing_cards",
				sub = "points",
				value = C.card_point_tap_points,
				priority = C.default_effect_priority,
			},
		},
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
		visual = V(),
		effects = {
			{
				effect_name = "add_points",
				macro = "playing_cards",
				sub = "points",
				value = C.card_point_push_points,
				priority = C.default_effect_priority,
			},
		},
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
		visual = V(),
		effects = {
			{
				effect_name = "add_mult",
				macro = "playing_cards",
				sub = "mult",
				value = C.card_small_mult_plus_mult,
				priority = C.default_effect_priority,
			},
		},
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
		visual = V(),
		effects = {
			{
				effect_name = "add_mult",
				macro = "playing_cards",
				sub = "mult",
				value = C.card_big_mult_plus_mult,
				priority = C.default_effect_priority,
			},
		},
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
		visual = V(),
		effects = {
			{
				effect_name = "add_points",
				macro = "playing_cards",
				sub = "points",
				value = C.card_balanced_boost_points,
				priority = C.default_effect_priority,
			},
			{
				effect_name = "add_mult",
				macro = "playing_cards",
				sub = "mult",
				value = C.card_balanced_boost_plus_mult,
				priority = C.default_effect_priority,
			},
		},
	},
	card_steel = {
		id = "card_steel",
		type = "card",
		name = "Steel",
		description = "A steel card with no immediate effects.",
		display_name = "Steel",
		rarity = "common",
		probability = 1.0,
		cost = 1,
		energy_cost = 1,
		tags = { "steel" },
		visual = V({ graphic = "sprites/stones/tower.png" }),
		effects = {},
	},
	card_focus_stance = {
		id = "card_focus_stance",
		type = "card",
		name = "Focus Stance",
		description = "Creates a temporary +5 points stance for 3 rounds.",
		display_name = "Focus Stance",
		rarity = "rare",
		probability = 0.6,
		cost = 2,
		energy_cost = 2,
		tags = {},
		visual = V(),
		effects = {
			{
				effect_name = "create_temporary_stance",
				macro = "playing_cards",
				sub = "points",
				value = {
					stance_id = "stance_focus_bonus",
					rounds = C.card_focus_stance_rounds,
					points = C.card_focus_stance_points,
				},
				priority = C.card_focus_stance_effect_priority,
			},
		},
	},
	card_destroy_enemy_stone = {
		id = "card_destroy_enemy_stone",
		type = "card",
		name = "Shatter Mark",
		description = "Target an enemy stone. Destroy it with 1/4 chance.",
		display_name = "Shatter Mark",
		rarity = "rare",
		probability = 0.5,
		cost = 2,
		energy_cost = 2,
		visual = V(),
		targeting = { kind = "board_stone", rule = "enemy" },
		effects = {
			{
				effect_name = "destroy_selected_enemy_stone",
				macro = "playing_cards",
				sub = "points",
				value = {
					chance_numerator = C.card_destroy_chance_numerator,
					chance_denominator = C.card_destroy_chance_denominator,
				},
				priority = C.default_effect_priority,
				conditions = {
					{ condition_name = "selected_target_exists" },
					{ condition_name = "selected_target_is_enemy_stone" },
				},
			},
		},
	},
	card_forge_mark = {
		id = "card_forge_mark",
		type = "card",
		name = "Forge Mark",
		description = "Target a friendly board stone. Permanently add +10 points for this game.",
		display_name = "Forge Mark",
		rarity = "rare",
		probability = 0.5,
		cost = 2,
		energy_cost = 2,
		visual = V(),
		targeting = { kind = "board_stone", rule = "friendly" },
		effects = {
			{
				effect_name = "add_permanent_points_to_selected_stone",
				macro = "playing_cards",
				sub = "points",
				value = { points = C.card_forge_mark_points },
				priority = C.default_effect_priority,
				conditions = {
					{ condition_name = "selected_target_exists" },
					{ condition_name = "selected_target_is_friendly_stone" },
				},
			},
		},
	},
}

return M
