local pose_effects = require("poses.effects")
local card_effects = require("playing_cards.effects")
local stone_effects = require("stones.effects")

local Effects = {
	poses = {},
	cards = {},
	stones = {},
}

function Effects.poses.resolve(pose, state)
	return pose_effects.resolve(pose, state)
end

function Effects.cards.resolve(card, state)
	return card_effects.resolve(card, state)
end

function Effects.stones.resolve(effect)
	return stone_effects.resolve(effect)
end

function Effects.stones.resolve_board_stone(stone_cell, state)
	return stone_effects.resolve_board_stone(stone_cell, state)
end

return Effects
