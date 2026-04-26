local board = require("board")
local array_utils = require("array_utils")
local config = require("config")
local content = require("content")
local deck = require("deck")
local pouch = require("pouch")

local M = {}

local ENERGY_MAX_DEFAULT = 3
local MONEY_DEFAULT = 0
local CARD_DECK_TARGET_SIZE = 10
local CARD_HAND_TARGET_SIZE = 4
local STONE_POUCH_TARGET_SIZE = 20
local STONE_HAND_TARGET_SIZE = 6

local MODULUS = 2147483647
local MULTIPLIER = 48271

local function next_rng_int(rng_state, max_value)
	rng_state.seed = (rng_state.seed * MULTIPLIER) % MODULUS
	return (rng_state.seed % max_value) + 1
end

local function make_side_rng(rng_state)
	return function(max_value)
		return next_rng_int(rng_state, max_value)
	end
end

local function build_pouch_seed_ids(source_ids, target_size, rng_next_int)
	local out = {}
	if #source_ids == 0 then
		return out
	end
	for _ = 1, target_size do
		local pick = rng_next_int(#source_ids)
		out[#out + 1] = source_ids[pick]
	end
	return out
end

local function build_deck_seed_ids(source_ids, target_size, rng_next_int)
	local out = {}
	if #source_ids == 0 then
		return out
	end
	for _ = 1, target_size do
		local pick = rng_next_int(#source_ids)
		out[#out + 1] = source_ids[pick]
	end
	return out
end

local function draw_stones_to_hand(pouch_state, hand_size)
	local hand = {}
	while #hand < hand_size do
		local stone_id = pouch.draw(pouch_state)
		if not stone_id then
			break
		end
		hand[#hand + 1] = stone_id
	end
	return hand
end

local function build_player(side, starter, rng_next_int)
	local starter_poses = starter.poses
	local pouch_seed_ids = build_pouch_seed_ids(starter.pouch, STONE_POUCH_TARGET_SIZE, rng_next_int)
	local starter_pouch = pouch.shuffle_init(pouch_seed_ids, rng_next_int)
	local playable_stones = draw_stones_to_hand(starter_pouch, STONE_HAND_TARGET_SIZE)
	local deck_seed_ids = build_deck_seed_ids(starter.deck, CARD_DECK_TARGET_SIZE, rng_next_int)
	return {
		side = side,
		score = {
			points = 0,
			mult = 0,
			total = 0,
			points_bonus = 0,
			mult_bonus = 0,
		},
		resources = {
			energy_current = ENERGY_MAX_DEFAULT,
			energy_max = ENERGY_MAX_DEFAULT,
			money = MONEY_DEFAULT,
		},
		stones = {
			pouch = starter_pouch,
			playable_stones = playable_stones,
			selected_stone = playable_stones[1],
			hand_target_size = STONE_HAND_TARGET_SIZE,
		},
		cards = deck.new(deck_seed_ids, CARD_HAND_TARGET_SIZE, rng_next_int),
		poses = {
			fixed = array_utils.clone(starter_poses.fixed),
			swappable = array_utils.clone(starter_poses.swappable),
		},
		prisoners = 0,
	}
end

function M.new_match(match_kind, seed)
	local rng_seed = seed
	if not rng_seed then
		rng_seed = love.math.random(1, MODULUS - 1)
	end
	local rng_state = { seed = rng_seed }
	local rng_next_int = make_side_rng(rng_state)
	local black = build_player("black", content.starters.black, rng_next_int)
	local white = build_player("white", content.starters.white, rng_next_int)
	return {
		board = board.new(),
		to_play = "black",
		phase = "TURN_START",
		turn_number = 1,
		ended = false,
		end_reason = "none",
		winner = "none",
		ko_ban = nil,
		consecutive_passes = 0,
		messages = {
			queue = { "Match start: black to play" },
			recent = {},
		},
		players = {
			black = black,
			white = white,
		},
		rng = rng_state,
		match_kind = match_kind,
		versus_bot = match_kind == "pvc",
		ai_delay = 0,
		status = "",
	}
end

function M.rng_next_int(match_state, max_value)
	return next_rng_int(match_state.rng, max_value)
end

function M.player_for_color(match_state, color)
	if color == config.STONE_BLACK or color == "black" then
		return match_state.players.black
	end
	return match_state.players.white
end

return M
