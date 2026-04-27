local effects = require("stones.effects")

local M = {
	stone_basic = {
		id = "stone_basic",
		name = "Basic Stone",
		description = "Steady placement stone that adds 1 point on placement.",
		depiction = "Solid circle core",
		graphic = { draw_key = "solid" },
		placement_effects = {
			{ effect_name = "add_points", value = 1, priority = 10 },
		},
	},
	stone_power = {
		id = "stone_power",
		name = "Power Stone",
		description = "Heavy placement stone that adds 2 points on placement.",
		depiction = "Diamond center mark",
		graphic = { draw_key = "diamond" },
		placement_effects = {
			{ effect_name = "add_points", value = 2, priority = 10 },
		},
	},
	stone_focus = {
		id = "stone_focus",
		name = "Focus Stone",
		description = "Precision stone that adds 1 multiplier on placement.",
		depiction = "Ring with dot center",
		graphic = { draw_key = "ring" },
		placement_effects = {
			{ effect_name = "add_mult", value = 1, priority = 10 },
		},
	},
}

return M
