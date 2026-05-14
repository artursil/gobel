--- Unified stone definitions (gameplay + **visual**).
---
--- **Graphics-first checklist** for a new stone:
--- 1. Add a row here with unique ``id``, ``type = "stone"``, name/description/cost/rarity, ``effects``.
--- 2. Set ``visual.color`` (RGB 0–1 tint for the body) and ``visual.sprite`` (PNG path under ``sprites/``).
--- 3. Keep ``graphic.draw_key`` only as a fallback when the sprite fails to load (optional; tests may assert it).
--- 4. Register pouch/deck counts in ``game_types`` / ``content.starters`` as needed.
--- @module objects.definitions.stones

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
	effects = {
		{ effect_name = "add_points", phase = "points", value = 1, priority = 10 },
	},
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
		{ effect_name = "add_points", phase = "points", value = 2, priority = 10 },
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
		{ effect_name = "add_mult", phase = "mult", value = 1, priority = 10 },
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
		{ effect_name = "add_points", phase = "points", value = 1, priority = 10 },
		{ effect_name = "distance_bonus", phase = "distance", value = 1, priority = 10 },
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
		{ effect_name = "add_points", phase = "points", value = 1, priority = 10 },
		{ effect_name = "double_corner_nearby_territory", phase = "territory", priority = 10 },
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

M.stone_wall = {
	id = "stone_wall",
	type = "stone",
	name = "Wall",
	description = "A defensive wall stone used for tag-triggered effects.",
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
	effects = {},
}

return M
