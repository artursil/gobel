local effects = require("stones.effects")

local M = {
	stone_basic = {
		id = "stone_basic",
		name = "Basic Stone",
		description = "Steady placement stone that adds 1 point on placement.",
		depiction = "Solid circle core",
		graphic = { draw_key = "solid" },
		behavior = effects.add_points(1),
	},
	stone_power = {
		id = "stone_power",
		name = "Power Stone",
		description = "Heavy placement stone that adds 2 points on placement.",
		depiction = "Diamond center mark",
		graphic = { draw_key = "diamond" },
		behavior = effects.add_points(2),
	},
	stone_focus = {
		id = "stone_focus",
		name = "Focus Stone",
		description = "Precision stone that adds 1 multiplier on placement.",
		depiction = "Ring with dot center",
		graphic = { draw_key = "ring" },
		behavior = effects.add_mult(1),
	},
}

return M
