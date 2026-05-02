--- Stone content definitions: placement payloads and default `behavior` producers.
--- @module stones.definitions

local M = {}

M.stone_basic = {
	id = "stone_basic",
	name = "Basic Stone",
	description = "Steady placement stone that adds 1 point on placement.",
	depiction = "Solid circle core",
	graphic = { draw_key = "solid" },
	effects = {
		{ effect_name = "add_points", phase = "points", value = 1, priority = 10 },
	},
}
M.stone_power = {
	id = "stone_power",
	name = "Power Stone",
	description = "Heavy placement stone that adds 2 points on placement.",
	depiction = "Diamond center mark",
	graphic = { draw_key = "diamond" },
	effects = {
		{ effect_name = "add_points", phase = "points", value = 2, priority = 10 },
	},
}
M.stone_focus = {
	id = "stone_focus",
	name = "Focus Stone",
	description = "Precision stone that adds 1 multiplier on placement.",
	depiction = "Ring with dot center",
	graphic = { draw_key = "ring" },
	effects = {
		{ effect_name = "add_mult", phase = "mult", value = 1, priority = 10 },
	},
}

M.stone_lieutenant = {
	id = "stone_lieutenant",
	name = "Lieutenant",
	description = "Skilled commander whose presence extends your reach by 1 when calculating territory.",
	depiction = "Chevron mark",
	graphic = { draw_key = "chevron" },
	effects = {
		{ effect_name = "add_points", phase = "points", value = 1, priority = 10 },
		{ effect_name = "distance_bonus", phase = "distance", value = 1, priority = 10 },
	},
}

M.stone_tower = {
	id = "stone_tower",
	name = "Tower",
	description = "When placed in a corner, doubles territory value of the surrounding 8 tiles.",
	depiction = "Square tower outline",
	graphic = { draw_key = "tower" },
	effects = {
		{ effect_name = "add_points", phase = "points", value = 1, priority = 10 },
		{ effect_name = "double_corner_nearby_territory", phase = "territory", priority = 10 },
	},
}

return M
