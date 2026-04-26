local M = {}
local stone_behaviors = require("stone_behaviors")

M.stones = {
	stone_basic = {
		id = "stone_basic",
		name = "Basic Stone",
		description = "Steady placement stone that adds 1 point on placement.",
		depiction = "Solid circle core",
		graphic = { draw_key = "solid" },
		behavior = stone_behaviors.add_points(1),
	},
	stone_power = {
		id = "stone_power",
		name = "Power Stone",
		description = "Heavy placement stone that adds 2 points on placement.",
		depiction = "Diamond center mark",
		graphic = { draw_key = "diamond" },
		behavior = stone_behaviors.add_points(2),
	},
	stone_focus = {
		id = "stone_focus",
		name = "Focus Stone",
		description = "Precision stone that adds 1 multiplier on placement.",
		depiction = "Ring with dot center",
		graphic = { draw_key = "ring" },
		behavior = stone_behaviors.add_mult(1),
	},
}

M.cards = {
	card_point_tap = {
		id = "card_point_tap",
		display_name = "Point Tap",
		energy_cost = 1,
		effects = { { type = "ADD_POINTS", value = 2 } },
	},
	card_point_push = {
		id = "card_point_push",
		display_name = "Point Push",
		energy_cost = 2,
		effects = { { type = "ADD_POINTS", value = 4 } },
	},
	card_small_mult = {
		id = "card_small_mult",
		display_name = "Small Mult",
		energy_cost = 1,
		effects = { { type = "ADD_MULT", value = 1 } },
	},
	card_big_mult = {
		id = "card_big_mult",
		display_name = "Big Mult",
		energy_cost = 2,
		effects = { { type = "ADD_MULT", value = 2 } },
	},
	card_balanced_boost = {
		id = "card_balanced_boost",
		display_name = "Balanced Boost",
		energy_cost = 2,
		effects = {
			{ type = "ADD_POINTS", value = 2 },
			{ type = "ADD_MULT", value = 1 },
		},
	},
}

M.poses = {
	pose_point_stance = {
		id = "pose_point_stance",
		display_name = "Point Stance",
		trigger = "TURN_START",
		effect = { type = "ADD_POINTS", value = 1 },
	},
	pose_mult_stance = {
		id = "pose_mult_stance",
		display_name = "Mult Stance",
		trigger = "TURN_START",
		effect = { type = "ADD_MULT", value = 1 },
	},
	pose_heavy_point_stance = {
		id = "pose_heavy_point_stance",
		display_name = "Heavy Point Stance",
		trigger = "TURN_START",
		effect = { type = "ADD_POINTS", value = 2 },
	},
}

M.starters = {
	black = {
		poses = {
			fixed = { "pose_point_stance" },
			swappable = { "pose_mult_stance" },
		},
		pouch = {
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_power",
			"stone_power",
			"stone_power",
			"stone_focus",
			"stone_focus",
			"stone_focus",
		},
		deck = {
			"card_point_tap",
			"card_point_tap",
			"card_point_tap",
			"card_point_push",
			"card_point_push",
			"card_small_mult",
			"card_small_mult",
			"card_big_mult",
			"card_balanced_boost",
			"card_balanced_boost",
		},
	},
	white = {
		poses = {
			fixed = { "pose_mult_stance" },
			swappable = { "pose_heavy_point_stance" },
		},
		pouch = {
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_basic",
			"stone_power",
			"stone_power",
			"stone_power",
			"stone_focus",
			"stone_focus",
			"stone_focus",
		},
		deck = {
			"card_point_tap",
			"card_point_tap",
			"card_point_tap",
			"card_point_push",
			"card_point_push",
			"card_small_mult",
			"card_small_mult",
			"card_big_mult",
			"card_balanced_boost",
			"card_balanced_boost",
		},
	},
}

function M.get_stone(stone_id)
	return M.stones[stone_id]
end

function M.get_card(card_id)
	return M.cards[card_id]
end

function M.get_pose(pose_id)
	return M.poses[pose_id]
end

return M
