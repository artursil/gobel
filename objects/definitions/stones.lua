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

M.escalating_money_stone = {
	id = "escalating_money_stone",
	type = "stone",
	name = "Escalating Money Stone",
	description = "Each owner end of turn adds money and tracks cumulative received; on capture the owner pays a multiple of total received.",
	rarity = "rare",
	probability = 0.6,
	cost = 1,
	depiction = "Coin stack mark",
	graphic = { draw_key = "ring" },
	visual = {
		color = { 0.78, 0.68, 0.28 },
		sprite = "sprites/stones/special.png",
	},
	effects = {
		{
			effect_name = "escalating_money_tracker",
			macro = "end_of_turn",
			sub = "points",
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
	"points_stone",
	"influence_stone",
	"tower_stone",
	"energy_stone",
	"diagonal_stone",
	"line_stone",
	"kamikaze_stone",
	"enclosure_stone",
	"control_stone",
	"blockade_stone",
	"defence_stone",
	"money_field_stone",
	"anti_capture_stone",
	"delay_reward_stone",
	"capture_stone",
	"tax_stone",
	"self_destruct_timed_stone",
	"territory_to_points_stone",
	"territory_to_multiplier_stone",
	"escalating_points_stone",
	"high_power_money_loss_stone",
}

local LATER_IMPLMENTED_STONE_IDS = {
	"unlimited_upgrades_stone",
	"final_blow_stone",
	"copper_stone",
	"retrigger_stone",
}

for i = 1, #UNIMPLEMENTED_STONE_IDS do
	local id = UNIMPLEMENTED_STONE_IDS[i]
	M[id] = stub_stone(id)
end
for i = 1, #LATER_IMPLMENTED_STONE_IDS do
	local id = LATER_IMPLMENTED_STONE_IDS[i]
	M[id] = stub_stone(id)
end

return M
