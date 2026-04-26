local config = require("config")
local match_state = require("match_state")
local resolver = require("resolver")
local rules = require("rules")
require("spec.test_helper")

local function new_started_state(seed)
	local state = match_state.new_match("pvp", seed or 1)
	state.players.black.poses.fixed = {}
	state.players.black.poses.swappable = {}
	state.players.white.poses.fixed = {}
	state.players.white.poses.swappable = {}
	local started = resolver.begin_turn(state, "black")
	assert.is_true(started.ok)
	return state
end

describe("T-050 resolver and core system correctness", function()
	it("plays card from hand, spends energy, and enqueues effect message", function()
		local state = new_started_state(11)
		local black = state.players.black
		black.cards.hand.ids = { "card_point_tap" }
		black.cards.discard.ids = {}
		black.resources.energy_current = 1
		black.score.points_bonus = 0

		local result = resolver.submit_action(state, {
			actor = "black",
			type = "PLAY_CARD",
			payload = { hand_index = 1 },
		})

		assert.is_true(result.ok)
		assert.are.equal("MAIN_PHASE", state.phase)
		assert.are.equal(0, black.resources.energy_current)
		assert.are.same({}, black.cards.hand.ids)
		assert.are.same({ "card_point_tap" }, black.cards.discard.ids)
		assert.are.equal(2, black.score.points_bonus)
		assert.are.equal("Point Tap: +2 points", state.messages.recent[#state.messages.recent])
	end)

	it("rejects card play with insufficient energy without partial mutation", function()
		local state = new_started_state(12)
		local black = state.players.black
		black.cards.hand.ids = { "card_point_push" }
		black.cards.discard.ids = {}
		black.resources.energy_current = 1
		black.score.points_bonus = 0

		local result = resolver.submit_action(state, {
			actor = "black",
			type = "PLAY_CARD",
			payload = { hand_index = 1 },
		})

		assert.is_false(result.ok)
		assert.are.equal("Insufficient energy", result.error)
		assert.are.same({ "card_point_push" }, black.cards.hand.ids)
		assert.are.same({}, black.cards.discard.ids)
		assert.are.equal(1, black.resources.energy_current)
		assert.are.equal(0, black.score.points_bonus)
	end)

	it("rejects invalid hand index without state mutation", function()
		local state = new_started_state(13)
		local black = state.players.black
		black.cards.hand.ids = { "card_point_tap" }
		black.cards.discard.ids = {}

		local result = resolver.submit_action(state, {
			actor = "black",
			type = "PLAY_CARD",
			payload = { hand_index = 0 },
		})

		assert.is_false(result.ok)
		assert.are.equal("Invalid hand index", result.error)
		assert.are.same({ "card_point_tap" }, black.cards.hand.ids)
		assert.are.same({}, black.cards.discard.ids)
	end)

	it("applies stone placement, consumes selected stone, and advances turn", function()
		local state = new_started_state(14)
		local black = state.players.black
		black.stones.playable_stones = { "stone_basic" }
		black.stones.selected_stone = "stone_basic"
		black.score.points_bonus = 0
		resolver.finish_main_phase(state, "black")

		local legal_moves = rules.all_legal_moves(state.board, config.STONE_BLACK, state.ko_ban, "stone_basic")
		local move = legal_moves[1]
		local result = resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = move[1], col = move[2] },
		})

		assert.is_true(result.ok)
		assert.are.equal("Basic Stone placement: +1 points", state.messages.recent[#state.messages.recent])
		assert.are.equal("white", state.to_play)
		assert.are.equal("MAIN_PHASE", state.phase)
		assert.are.equal(1, black.score.points_bonus)
		assert.are.same({}, black.stones.playable_stones)
		assert.is_nil(black.stones.selected_stone)
	end)

	it("keeps money unchanged across card and stone actions", function()
		local state = new_started_state(15)
		local black = state.players.black
		black.resources.money = 0
		black.cards.hand.ids = { "card_point_tap" }
		black.resources.energy_current = 3

		local play_result = resolver.submit_action(state, {
			actor = "black",
			type = "PLAY_CARD",
			payload = { hand_index = 1 },
		})
		assert.is_true(play_result.ok)
		assert.are.equal(0, black.resources.money)

		resolver.finish_main_phase(state, "black")
		black.stones.playable_stones = { "stone_basic" }
		black.stones.selected_stone = "stone_basic"
		local legal_moves = rules.all_legal_moves(state.board, config.STONE_BLACK, state.ko_ban, "stone_basic")
		local move = legal_moves[1]
		local place_result = resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = move[1], col = move[2] },
		})
		assert.is_true(place_result.ok)
		assert.are.equal(0, black.resources.money)
	end)
end)
