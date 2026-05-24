--- Unified stone definitions (gameplay + **visual**).
---
--- **Graphics-first checklist** for a new stone:
--- 1. Add a row here with unique ``id``, ``type = "stone"``, name/description/cost/rarity, ``effects``.
--- 2. Set ``visual.color`` (RGB 0–1 tint for the body) and ``visual.sprite`` (PNG path under ``sprites/``).
--- 3. Keep ``graphic.draw_key`` only as a fallback when the sprite fails to load (optional; tests may assert it).
--- 4. Register pouch/deck counts in ``game_types`` / ``content.starters`` as needed.
--- @module objects.definitions.stones

local shared = require("objects.definitions.shared_stones_effects")

local M = {}

M.stone_basic = {
	id = "stone_basic",
	type = "stone",
	name = "Basic Stone",
	description = "Steady placement stone that adds 1 point on placement.",
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
	depiction = "Diamond center mark",
	graphic = { draw_key = "diamond" },
	visual = {
		color = { 0.45, 0.55, 0.75 },
		sprite = "sprites/stones/power.png",
	},
	effects = {
		{ effect_name = "add_points", macro = "playing_stones", sub = "points", value = 2, priority = 10 },
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
		{ effect_name = "add_mult", macro = "playing_stones", sub = "mult", value = 1, priority = 10 },
	},
}

M.stone_lieutenant = {
	id = "stone_lieutenant",
	type = "stone",
	name = "Lieutenant",
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
			value = 1,
			priority = 10,
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
			priority = 10,
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
	description = "When a placement completes an X, multiplies ×Mult by 2 for each x_stone in that X.",
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
	description = "When part of a completed + on the board, adds +5 Plus mult per pattern tier (needs a plus stone in the +).",
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
	description = "When placed, adds +5 Points for every 5 stones in its orthogonal connected group (including the wall).",
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

return M
