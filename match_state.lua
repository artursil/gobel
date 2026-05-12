local board = require("board")
local array_utils = require("array_utils")
local config = require("config")
local content = require("content")
local deck = require("deck")
local pouch = require("pouch")

local M = {}

--- @param turn_number integer
--- @return integer
function M.round_number_from_turn(turn_number)
	return math.floor((turn_number or 1) / 2) + 1
end

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
	local pouch_seed_ids = build_pouch_seed_ids(starter.pouch, STONE_POUCH_TARGET_SIZE, rng_next_int)
	local starter_pouch = pouch.shuffle_init(pouch_seed_ids, rng_next_int)
	local playable_stones = draw_stones_to_hand(starter_pouch, STONE_HAND_TARGET_SIZE)
	local deck_seed_ids = build_deck_seed_ids(starter.deck, CARD_DECK_TARGET_SIZE, rng_next_int)
	return {
		side = side,
		score = {
			turn_bonus = 1,
			territory = 0,
			points = 0,
			plus_mult = 1,
			x_mult = 1,
			total = 0,
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
			selected_stone_index = (#playable_stones > 0) and 1 or nil,
			hand_target_size = STONE_HAND_TARGET_SIZE,
		},
	cards = deck.new(deck_seed_ids, CARD_HAND_TARGET_SIZE, rng_next_int),
	stances = {
		fixed = array_utils.clone(starter.stances.fixed),
		swappable = array_utils.clone(starter.stances.swappable),
	},
	prisoners = 0,
	}
end

local function is_bot_mode(match_kind)
	return match_kind == "pvc" or match_kind == "pvc_basic"
end

function M.new_match(match_kind, territory_mode, seed)
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
		round_number = M.round_number_from_turn(1),
		ended = false,
		end_reason = "none",
		winner = "none",
		ko_ban = nil,
		consecutive_passes = 0,
		messages = {
			queue = { "Match start: black to play" },
			recent = {},
			score_events = {},
		},
		players = {
			black = black,
			white = white,
		},
		just_played = {},
		played_cards = {},
		last_played_stone = nil,
		last_opponent_move = nil,
		last_opponent_modifiers = {},
		active_effects = {},
		round_stone_effects = {},
		ui_animation_events = {},
		stone_draw_events = {},
		resolution = {
			phase = nil,
			effect_owner = nil,
			source_owner = nil,
			source_def_id = nil,
			source_instance_id = nil,
			source_object_type = nil,
			source_stance_index = nil,
			source_stance_slot_index = nil,
			selected_target = nil,
			trigger = nil,
		},
		selected_card_target = nil,
		board_stone_modifiers = {},
		territory_value = (function()
			local n = config.BOARD_SIZE
			local tv = {}
			for r = 1, n do
				tv[r] = {}
				for c = 1, n do
					tv[r][c] = 1
				end
			end
			return tv
		end)(),
		scores = {
			turn_bonus = { B = 1, W = 1 },
			territory = { B = 0, W = 0 },
			points = { B = 0, W = 0 },
			plus_mult = { B = 1, W = 1 },
			x_mult = { B = 1, W = 1 },
		},
		rng = rng_state,
		match_kind = match_kind,
		territory_mode = territory_mode or "regional",
		versus_bot = is_bot_mode(match_kind),
		ai_delay = 0,
		animation_speed = 1,
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
