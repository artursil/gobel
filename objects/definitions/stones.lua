--- Unified stone definitions.
--- Source of truth for all stone content.
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
	effects = {},
}

return M
