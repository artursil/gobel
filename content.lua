local M = {}
M.stones = require("stones.definitions")
M.cards = require("playing_cards.definitions")
M.poses = require("poses.definitions")

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
