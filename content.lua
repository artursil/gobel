--- Central content loader: loads all definitions from objects/
--- @module content

local M = {}

--- Load all definitions from unified objects/ module
M.stones = require("objects.definitions.stones")
M.stances = require("objects.definitions.stances")
M.cards = require("objects.definitions.cards")

--- Temporary compat alias for poses (to be removed in PR 2)
M.poses = M.stances

M.starters = {
	black = {
		stances = {
			fixed = { "stance_point" },
			swappable = { "stance_mult" },
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
		stances = {
			fixed = { "stance_mult" },
			swappable = { "stance_heavy_point" },
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

--- Get stone definition by ID.
--- @param stone_id string
--- @return table|nil
function M.get_stone(stone_id)
	return M.stones[stone_id]
end

--- Get card definition by ID.
--- @param card_id string
--- @return table|nil
function M.get_card(card_id)
	return M.cards[card_id]
end

--- Get stance definition by ID. Replaces old get_pose.
--- @param stance_id string
--- @return table|nil
function M.get_stance(stance_id)
	return M.stances[stance_id]
end

--- Deprecated compat alias for get_stance.
function M.get_pose(pose_id)
	return M.get_stance(pose_id)
end

return M
