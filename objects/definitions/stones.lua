--- Unified stone definitions (gameplay + **visual**).
---
--- **Graphics-first checklist** for a new stone:
--- 1. Add a row here with unique ``id``, ``type = "stone"``, name/description/cost/rarity, ``effects``.
--- 2. Optional ``solidity`` (max health); omit to use ``objects.parameters.stones.default_solidity``.
--- 3. Set ``visual.color`` (RGB 0–1 tint for the overlay) and ``visual.sprite`` (PNG path under ``sprites/``).
--- 4. Keep ``graphic.draw_key`` only as a fallback when the sprite fails to load (optional; tests may assert it).
--- 5. Board render uses ``sprites/stones/stones.png`` deterioration base + centered type overlay.
--- 6. Register pouch/deck counts in ``game_types`` / ``content.starters`` as needed.
--- @module objects.definitions.stones

local shared = require("objects.definitions.shared_stones_effects")
local stone_params = require("objects.parameters.stones")

local P = stone_params
local M = {}

M.stone_basic = {
	id = "stone_basic",
	type = "stone",
	name = "Basic Stone",
	description = "Inert placement stone with no stone-specific scoring or multiplier effects.",
	rarity = "common",
	probability = 1.0,
	cost = 1,
	depiction = "Solid circle core",
	graphic = { draw_key = "solid" },
	visual = {
		color = { 0.72, 0.7, 0.68 },
		sprite = "sprites/stones/basic.png",
	},
	effects = {},
}

M.stone_power = {
	id = "stone_power",
	type = "stone",
	name = "Power Stone",
	description = "Heavy placement stone that adds 2 points on placement.",
	rarity = "uncommon",
	probability = 0.8,
	cost = 1,
	max_level = 1,
	upgrade_levels = {
		[1] = {},
		[2] = {
			effect_deltas = {
				add_points = { macro = "playing_stones", sub = "points", delta = 1 },
			},
		},
	},
	depiction = "Diamond center mark",
	graphic = { draw_key = "diamond" },
	visual = {
		color = { 0.45, 0.55, 0.75 },
		sprite = "sprites/stones/power.png",
	},
	effects = {
		{
			effect_name = "add_points",
			macro = "playing_stones",
			sub = "points",
			value = P.stone_power_placement_points,
			priority = P.default_effect_priority,
		},
	},
}

M.stone_focus = {
	id = "stone_focus",
	type = "stone",
	name = "Focus Stone",
	description = "Precision stone that adds 1 multiplier on placement.",
	rarity = "common",
	probability = 1.0,
	cost = 1,
	depiction = "Ring with dot center",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.55, 0.72, 0.55 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "add_mult",
			macro = "playing_stones",
			sub = "mult",
			value = P.stone_focus_placement_plus_mult,
			priority = P.default_effect_priority,
		},
	},
}

M.influence_stone = {
	id = "influence_stone",
	type = "stone",
	name = "Influence Stone",
	description = "Extends territory reach by tier when calculating distance-based ownership.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	max_level = 3,
	upgrade_levels = {
		[1] = {},
		[2] = {
			effect_deltas = {
				distance_bonus = {
					macro = "playing_stones",
					sub = "territory",
					delta = P.influence_t2 - P.influence_t1,
				},
			},
		},
		[3] = {
			effect_deltas = {
				distance_bonus = {
					macro = "playing_stones",
					sub = "territory",
					delta = P.influence_t3 - P.influence_t2,
				},
			},
		},
	},
	depiction = "Chevron mark",
	graphic = { draw_key = "diamond" },
	visual = {
		color = { 0.5, 0.45, 0.62 },
		sprite = "sprites/stones/lieutenant.png",
	},
	effects = {
		{
			effect_name = "distance_bonus",
			macro = "playing_stones",
			sub = "territory",
			territory_step = "distance",
			territory_scope = "board",
			value = P.influence_t1,
			priority = P.default_effect_priority,
		},
	},
}

M.stone_influence = {
	id = "stone_influence",
	type = "stone",
	name = "Lieutenant",
	aliases = { "lieutenant" },
	description = "Skilled commander whose presence extends your reach by 1 when calculating territory.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Chevron mark",
	graphic = { draw_key = "diamond" },
	visual = {
		color = { 0.5, 0.45, 0.62 },
		sprite = "sprites/stones/lieutenant.png",
	},
	effects = {
		{
			effect_name = "distance_bonus",
			macro = "playing_stones",
			sub = "territory",
			territory_step = "distance",
			territory_scope = "board",
			value = P.stone_influence_distance_bonus,
			priority = P.default_effect_priority,
		},
	},
}

M.stone_tower = {
	id = "stone_tower",
	type = "stone",
	name = "Tower",
	description = "When placed in a corner, doubles territory value of the surrounding 8 tiles.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Square tower outline",
	graphic = { draw_key = "tower" },
	visual = {
		color = { 0.45, 0.32, 0.22 },
		sprite = "sprites/stones/tower.png",
	},
	effects = {
		{
			effect_name = "double_corner_nearby_territory",
			macro = "playing_stones",
			sub = "territory",
			territory_step = "value",
			territory_scope = "board",
			priority = P.default_effect_priority,
		},
	},
}

M.tower_stone = {
	id = "tower_stone",
	type = "stone",
	name = "Tower Stone",
	description = "Corner-only territory value amplifier. In a board corner, surrounding cells score higher territory value.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Square tower outline",
	graphic = { draw_key = "tower" },
	visual = {
		color = { 0.45, 0.32, 0.22 },
		sprite = "sprites/stones/tower.png",
	},
	effects = {
		{
			effect_name = "double_corner_nearby_territory",
			macro = "playing_stones",
			sub = "territory",
			territory_step = "value",
			territory_scope = "board",
			priority = P.default_effect_priority,
		},
	},
}

M.enclosure_stone = {
	id = "enclosure_stone",
	type = "stone",
	name = "Enclosure Stone",
	description = "When placed inside owner-enclosed territory, doubles field values in that enclosure.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Nested ring mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.55, 0.62, 0.48 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "enclosure_territory_multiply",
			macro = "playing_stones",
			sub = "territory",
			territory_step = "value",
			territory_scope = "board",
			value = P.enclosure_stone_multiplier,
			priority = P.default_effect_priority,
		},
	},
}

M.territory_to_points_stone = {
	id = "territory_to_points_stone",
	type = "stone",
	name = "Territory to Points Stone",
	description = "Each end of turn, pays points to the territory owner at this cell based on that owner's total controlled territory.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Territory yield mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.52, 0.68, 0.42 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "territory_to_points",
			macro = "end_of_turn",
			sub = "points",
			priority = P.default_effect_priority,
		},
	},
}

M.control_territory_stone = {
	id = "control_territory_stone",
	type = "stone",
	name = "Control Mult Stone",
	description = "On placement, adds multiplier based on territory control streak at the cell.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Triple-ring mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.62, 0.48, 0.72 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "mult_control_streak",
			macro = "playing_stones",
			sub = "mult",
			priority = P.default_effect_priority,
		},
	},
}

M.money_field_stone = {
	id = "money_field_stone",
	type = "stone",
	name = "Money Field Stone",
	description = "On placement in owner-enclosed territory, adds money_field_payout; otherwise zero.",
	rarity = "uncommon",
	probability = 0.7,
	cost = 1,
	depiction = "Coin field mark",
	graphic = { draw_key = "solid" },
	visual = {
		color = { 0.78, 0.68, 0.28 },
		sprite = "sprites/stones/basic.png",
	},
	effects = {
		{
			effect_name = "money_field_enclosure_payout",
			macro = "playing_stones",
			sub = "points",
			priority = P.default_effect_priority,
		},
	},
}

M.anti_capture_stone = {
	id = "anti_capture_stone",
	type = "stone",
	name = "Anti-Capture Stone",
	description = "On placement, grants temporary capture immunity to this stone and orthogonally connected own stones.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Shield ring mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.55, 0.68, 0.82 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "anti_capture_immunity",
			macro = "playing_stones",
			sub = "points",
			priority = P.default_effect_priority,
		},
	},
}

M.delay_reward_stone = {
	id = "delay_reward_stone",
	type = "stone",
	name = "Delay Reward Stone",
	description = "Survives on the board for "
		.. tostring(P.points_delay_rounds)
		.. " rounds, then grants "
		.. tostring(P.points_delay_payout)
		.. " points once if still present.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Hourglass mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.55, 0.62, 0.78 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "delay_reward_survival",
			macro = "playing_stones",
			sub = "points",
			rounds = P.points_delay_rounds,
			payout = P.points_delay_payout,
			priority = P.default_effect_priority,
		},
	},
}

M.stone_special = {
	id = "stone_special",
	type = "stone",
	name = "Special",
	description = "A special stone that triggers bonuses when placed.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	tags = { "special" },
	depiction = "Star symbol",
	graphic = { draw_key = "star" },
	visual = {
		color = { 0.85, 0.72, 0.35 },
		sprite = "sprites/stones/special.png",
	},
	effects = {},
}

M.x_stone = {
	id = "x_stone",
	type = "stone",
	name = "X Stone",
	description = "When a placement completes an X, multiplies ×Mult by "
		.. tostring(P.x_stone_mult_factor)
		.. " for each x_stone in that X.",
	rarity = "rare",
	probability = 0.5,
	cost = 1,
	depiction = "Diagonal cross mark",
	graphic = { draw_key = "star" },
	visual = {
		color = { 0.75, 0.4, 0.45 },
		sprite = "sprites/stones/special.png",
	},
	effects = {
	},
}

M.plus_stone = {
	id = "plus_stone",
	type = "stone",
	name = "Plus Stone",
	description = "When part of a completed + on the board, adds +"
		.. tostring(P.plus_stone_mult_add)
		.. " Plus mult per plus_stone in that +.",
	rarity = "rare",
	probability = 0.5,
	cost = 1,
	depiction = "Orthogonal cross mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.4, 0.65, 0.75 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
	},
}

M.energy_stone = {
	id = "energy_stone",
	type = "stone",
	name = "Energy Stone",
	description = "On placement, adds "
		.. tostring(P.energy_stone_gain)
		.. " energy (clamped to max; does not raise max energy).",
	rarity = "common",
	probability = 1.0,
	cost = 1,
	depiction = "Bolt center mark",
	graphic = { draw_key = "star" },
	visual = {
		color = { 0.85, 0.78, 0.35 },
		sprite = "sprites/stones/special.png",
	},
	effects = {
		{
			effect_name = "add_energy",
			macro = "playing_stones",
			sub = "points",
			value = P.energy_stone_gain,
			priority = P.default_effect_priority,
		},
	},
}

M.kamikaze_stone = {
	id = "kamikaze_stone",
	type = "stone",
	name = "Kamikaze Stone",
	description = "Sacrifice stone that may enter zero-liberty cells, pays "
		.. tostring(P.kamikaze_points_bonus)
		.. " points once, then removes itself from the board.",
	rarity = "uncommon",
	probability = 0.7,
	cost = 1,
	depiction = "Burst mark",
	graphic = { draw_key = "star" },
	visual = {
		color = { 0.85, 0.35, 0.3 },
		sprite = "sprites/stones/special.png",
	},
	effects = {
		{
			effect_name = "kamikaze_sacrifice",
			macro = "playing_stones",
			sub = "points",
			value = P.kamikaze_points_bonus,
			priority = P.default_effect_priority,
		},
	},
}

M.defence_stone = {
	id = "defence_stone",
	type = "stone",
	name = "Defence Stone",
	description = "Adds "
		.. tostring(P.defence_solidity_bonus)
		.. " solidity to itself and connected own stones while the defence network holds.",
	rarity = "uncommon",
	probability = 0.8,
	cost = 1,
	depiction = "Shield mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.55, 0.62, 0.72 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "defence_solidity_network",
			macro = "playing_stones",
			sub = "points",
			priority = P.default_effect_priority,
		},
	},
}

M.control_stone = {
	id = "control_stone",
	type = "stone",
	name = "Control Stone",
	description = "Overrides orthogonal adjacent empty cells to your color after enclosure and influence; still counts for regular distance assignment.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Control ring mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.58, 0.42, 0.62 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "control_territory_override",
			macro = "playing_stones",
			sub = "territory",
			territory_step = "override",
			territory_scope = "board",
			priority = P.default_effect_priority,
		},
	},
}

M.points_stone = {
	id = "points_stone",
	type = "stone",
	name = "Points Stone",
	description = "Direct points stone with three upgrade tiers on placement.",
	rarity = "common",
	probability = 1.0,
	cost = 1,
	max_level = 3,
	upgrade_levels = {
		[1] = {},
		[2] = {
			effect_deltas = {
				add_points = {
					macro = "playing_stones",
					sub = "points",
					delta = P.points_stone_t2 - P.points_stone_t1,
				},
			},
		},
		[3] = {
			effect_deltas = {
				add_points = {
					macro = "playing_stones",
					sub = "points",
					delta = P.points_stone_t3 - P.points_stone_t2,
				},
			},
		},
	},
	depiction = "Numeric tier mark",
	graphic = { draw_key = "diamond" },
	visual = {
		color = { 0.55, 0.65, 0.45 },
		sprite = "sprites/stones/power.png",
	},
	effects = {
		{
			effect_name = "add_points",
			macro = "playing_stones",
			sub = "points",
			value = P.points_stone_t1,
			priority = P.default_effect_priority,
		},
	},
}

M.capture_stone = {
	id = "capture_stone",
	type = "stone",
	name = "Capture Stone",
	description = "On placement, removes one enemy stone with zero liberties regardless of surrounding colors.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Crosshair mark",
	graphic = { draw_key = "star" },
	visual = {
		color = { 0.75, 0.35, 0.35 },
		sprite = "sprites/stones/special.png",
	},
	effects = {
		{
			effect_name = "capture_zero_liberty_enemy",
			macro = "playing_stones",
			sub = "points",
			priority = P.default_effect_priority,
		},
	},
}

M.wall = {
	id = "wall",
	type = "stone",
	name = "Wall",
	description = "When placed, adds +"
		.. tostring(P.wall_points_per_block)
		.. " Points for every "
		.. tostring(P.wall_stones_per_block)
		.. " stones in its orthogonal connected group (including the wall).",
	rarity = "common",
	probability = 1.0,
	cost = 1,
	tags = { "wall" },
	depiction = "Wall block icon",
	graphic = { draw_key = "tower" },
	visual = {
		color = { 0.42, 0.42, 0.46 },
		sprite = "sprites/stones/wall.png",
	},
	effects = {
		shared.wall_stone,
	},
}

M.diagonal_stone = {
	id = "diagonal_stone",
	type = "stone",
	name = "Diagonal Stone",
	description = "When placed, adds +"
		.. tostring(P.diagonal_stone_points_per_block)
		.. " Points for every "
		.. tostring(P.diagonal_stone_block_size)
		.. " stones in its diagonally connected group (including the placed stone).",
	rarity = "common",
	probability = 1.0,
	cost = 1,
	tags = { "diagonal" },
	depiction = "Diagonal link icon",
	graphic = { draw_key = "solid" },
	visual = {
		color = { 0.55, 0.68, 0.82 },
		sprite = "sprites/stones/basic.png",
	},
	effects = {
		shared.diagonal_group_points,
	},
}

M.line_stone = {
	id = "line_stone",
	type = "stone",
	name = "Line Stone",
	description = "When placed, adds +"
		.. tostring(P.line_stone_points_per_block)
		.. " Points for every "
		.. tostring(P.line_stone_block_size)
		.. " stones in its orthogonal connected group (including the line stone).",
	rarity = "common",
	probability = 0.8,
	cost = 1,
	depiction = "Horizontal line mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.45, 0.55, 0.82 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		shared.line_group_points,
	},
}

M.blockade_stone = {
	id = "blockade_stone",
	type = "stone",
	name = "Blockade Stone",
	description = "On placement, blocks opponent stones on orthogonally adjacent empty cells for "
		.. tostring(P.blockade_duration_rounds)
		.. " rounds.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Barrier ring mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.55, 0.35, 0.35 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "blockade_adjacent",
			macro = "playing_stones",
			sub = "points",
			priority = P.default_effect_priority,
		},
	},
}

M.tax_stone = {
	id = "tax_stone",
	type = "stone",
	name = "Tax Stone",
	description = "Each end of turn, taxes enemy stones inside the innermost owner enclosure containing this stone.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Coin ring mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.78, 0.62, 0.28 },
		sprite = "sprites/stones/special.png",
	},
	effects = {
		{
			effect_name = "tax_enclosure_enemies",
			macro = "end_of_turn",
			sub = "points",
			value = {
				money_per_enemy = P.tax_money_per_enemy,
				points_per_enemy = P.tax_points_per_enemy,
			},
			priority = P.default_effect_priority,
		},
	},
}

M.self_destruct_timed_stone = {
	id = "self_destruct_timed_stone",
	type = "stone",
	name = "Self-Destruct Timed Stone",
	description = "Adds "
		.. tostring(P.self_destruct_immediate_points)
		.. " points on placement, then self-removes after "
		.. tostring(P.self_destruct_delay_rounds)
		.. " rounds with no extra payout.",
	rarity = "uncommon",
	probability = 0.8,
	cost = 1,
	depiction = "Cracked core with timer ring",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.78, 0.42, 0.38 },
		sprite = "sprites/stones/special.png",
	},
	effects = {
		{
			effect_name = "self_destruct_timed",
			macro = "playing_stones",
			sub = "points",
			immediate_points = P.self_destruct_immediate_points,
			delay_rounds = P.self_destruct_delay_rounds,
			priority = P.default_effect_priority,
		},
	},
}

M.territory_to_multiplier_stone = {
	id = "territory_to_multiplier_stone",
	type = "stone",
	name = "Territory Mult Stone",
	description = "Each end of turn, adds plus mult to the player who owns the territory at this cell, "
		.. "based on that player's total controlled territory.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Territory multiplier sigil",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.55, 0.62, 0.78 },
		sprite = "sprites/stones/focus.png",
	},
	effects = {
		{
			effect_name = "territory_to_multiplier",
			macro = "end_of_turn",
			sub = "mult",
			priority = P.default_effect_priority,
		},
	},
}

M.escalating_points_stone = {
	id = "escalating_points_stone",
	type = "stone",
	name = "Escalating Points Stone",
	description = "Each end of turn adds "
		.. tostring(P.eps_round_points)
		.. " points to owner and this stone bank; enemy capture grants "
		.. tostring(P.eps_capture_multiplier)
		.. "× bank to the captor.",
	rarity = "uncommon",
	probability = 0.8,
	cost = 1,
	depiction = "Stacked point tiers",
	graphic = { draw_key = "diamond" },
	visual = {
		color = { 0.55, 0.72, 0.45 },
		sprite = "sprites/stones/power.png",
	},
	effects = {
		{
			effect_name = "escalating_points_bank",
			macro = "end_of_turn",
			sub = "points",
			value = P.eps_round_points,
			priority = P.default_effect_priority,
		},
	},
}

--- Placeholder stone def for unimplemented stones (no gameplay wiring yet).
--- @param id string
--- @return table
local function stub_stone(id)
	return {
		id = id,
		type = "stone",
		name = id,
		description = "",
		rarity = "common",
		probability = 1.0,
		cost = 1,
		graphic = { draw_key = "solid" },
		visual = {
			color = { 0.72, 0.7, 0.68 },
			sprite = "sprites/stones/basic.png",
		},
		effects = {},
	}
end

local UNIMPLEMENTED_STONE_IDS = {
	"escalating_money_stone",
	"high_power_money_loss_stone",
}

local TO_BE_IMPL_LATER_STONE_IDS = {
	"unlimited_upgrades_stone",
	"final_blow_stone",
	"copper_stone",
	"retrigger_stone",
}

for i = 1, #UNIMPLEMENTED_STONE_IDS do
	local id = UNIMPLEMENTED_STONE_IDS[i]
	M[id] = stub_stone(id)
end
for i = 1, #TO_BE_IMPL_LATER_STONE_IDS do
	local id = TO_BE_IMPL_LATER_STONE_IDS[i]
	M[id] = stub_stone(id)
end

return M
