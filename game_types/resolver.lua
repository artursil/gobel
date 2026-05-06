--- Applies game type configurations to match state
--- @module game_types.resolver

local config = require("config")
local pouch = require("pouch")
local deck = require("deck")
local definitions = require("game_types.definitions")

local M = {}

local function build_stone_pouch_from_config(stone_config, rng_next_int)
	local ids = {}
	for stone_id, count in pairs(stone_config) do
		for _ = 1, count do
			ids[#ids + 1] = stone_id
		end
	end
	return pouch.shuffle_init(ids, rng_next_int)
end

function M.apply_game_type(state, game_type_id)
	local game_type = definitions.get_game_type(game_type_id)
	if not game_type then
		return false
	end

	local match_state = require("match_state")
	local rng_next_int = function(max_value)
		return match_state.rng_next_int(state, max_value)
	end

	local black = state.players.black
	local white = state.players.white

	if game_type.black_stones then
		black.stones.pouch = build_stone_pouch_from_config(game_type.black_stones, rng_next_int)
		local hand = {}
		for i = 1, math.min(game_type.stone_hand_size or 6, 100) do
			local stone_id = pouch.draw(black.stones.pouch)
			if stone_id then
				hand[#hand + 1] = stone_id
			end
		end
		black.stones.playable_stones = hand
		black.stones.selected_stone = hand[1] or nil
		black.stones.hand_target_size = game_type.stone_hand_size or 6
	end

	if game_type.white_stones then
		white.stones.pouch = build_stone_pouch_from_config(game_type.white_stones, rng_next_int)
		local hand = {}
		for i = 1, math.min(game_type.stone_hand_size or 6, 100) do
			local stone_id = pouch.draw(white.stones.pouch)
			if stone_id then
				hand[#hand + 1] = stone_id
			end
		end
		white.stones.playable_stones = hand
		white.stones.selected_stone = hand[1] or nil
		white.stones.hand_target_size = game_type.stone_hand_size or 6
	end

	if game_type.black_deck then
		black.cards.deck.ids = game_type.black_deck
		black.cards.hand.ids = {}
	end

	if game_type.white_deck then
		white.cards.deck.ids = game_type.white_deck
		white.cards.hand.ids = {}
	end

	if game_type.black_initial_hand then
		black.cards.hand.ids = game_type.black_initial_hand
	end

	if game_type.white_initial_hand then
		white.cards.hand.ids = game_type.white_initial_hand
	end

	if game_type.black_poses then
		black.stances.fixed = game_type.black_poses.fixed or {}
		black.stances.swappable = game_type.black_poses.swappable or {}
	end

	if game_type.white_poses then
		white.stances.fixed = game_type.white_poses.fixed or {}
		white.stances.swappable = game_type.white_poses.swappable or {}
	end

	if game_type.black_stances then
		black.stances.fixed = game_type.black_stances.fixed or {}
		black.stances.swappable = game_type.black_stances.swappable or {}
	end

	if game_type.white_stances then
		white.stances.fixed = game_type.white_stances.fixed or {}
		white.stances.swappable = game_type.white_stances.swappable or {}
	end

	if game_type.black_energy_max then
		black.resources.energy_max = game_type.black_energy_max
		black.resources.energy_current = game_type.black_energy_max
	end

	if game_type.white_energy_max then
		white.resources.energy_max = game_type.white_energy_max
		white.resources.energy_current = game_type.white_energy_max
	end

	return true
end

return M
