local config = require("config")
local match_state = require("match_state")
local resolver = require("resolver")
local rules = require("rules")
require("spec.test_helper")

local P = require("spec.parameters_helper")

local function new_started_state(seed)
	local state = match_state.new_match("pvp", seed or 1)
	state.players.black.stances.fixed = {}
	state.players.black.stances.swappable = {}
	state.players.white.stances.fixed = {}
	state.players.white.stances.swappable = {}
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
		assert.are.equal(P.starting_points() + P.card_points("card_point_tap"), black.score.points)
		assert.are.equal(P.card_play_message("card_point_tap"), state.messages.recent[#state.messages.recent])
	end)

	it("rejects card play with insufficient energy without partial mutation", function()
		local state = new_started_state(12)
		local black = state.players.black
		black.cards.hand.ids = { "card_point_push" }
		black.cards.discard.ids = {}
		black.resources.energy_current = 1

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
		assert.are.equal(P.starting_points(), black.score.points)
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
		resolver.finish_main_phase(state, "black")

		local legal_moves = rules.all_legal_moves(state.board, config.STONE_BLACK, state.ko_ban, "stone_basic")
		local move = legal_moves[1]
		local result = resolver.submit_action(state, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = move[1], col = move[2] },
		})

		assert.is_true(result.ok)
		assert.are.equal(P.stone_placement_message("stone_basic"), state.messages.recent[#state.messages.recent])
		require("spec.test_helper").finish_ui_animations_for_turn(state)
		assert.are.equal("white", state.to_play)
		assert.are.equal("MAIN_PHASE", state.phase)
		assert.are.equal(P.starting_points(), black.score.points)
		assert.is_true(#black.stones.playable_stones >= 0)
		if black.stones.selected_stone then
			local selected_exists = false
			for i = 1, #black.stones.playable_stones do
				if black.stones.playable_stones[i] == black.stones.selected_stone then
					selected_exists = true
					break
				end
			end
			assert.is_true(selected_exists)
		end
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

	it("rejects invalid selected targets in resolver card play", function()
		local state = new_started_state(16)
		local black = state.players.black
		black.cards.hand.ids = { "card_attack_1" }
		black.cards.discard.ids = {}
		black.resources.energy_current = 3
		state.board[4][4] = require("board").make_stone(config.STONE_BLACK, "stone_basic", 4)

		local result = resolver.submit_action(state, {
			actor = "black",
			type = "PLAY_CARD",
			payload = {
				hand_index = 1,
				selected_targets = {
					{ object_type = "stone", row = 4, col = 4 },
				},
			},
		})

		assert.is_false(result.ok)
		assert.are.equal("Target owner mismatch", result.error)
		assert.are.same({ "card_attack_1" }, black.cards.hand.ids)
		assert.are.same({}, black.cards.discard.ids)
	end)

	it("plays card_money_discard_2, discards selected cards, and gains money", function()
		local state = new_started_state(17)
		local black = state.players.black
		black.cards.hand.ids = { "card_money_discard_2", "card_point_tap", "card_small_mult", "card_big_mult" }
		black.cards.discard.ids = {}
		black.resources.energy_current = 3
		black.resources.money = 0

		local result = resolver.submit_action(state, {
			actor = "black",
			type = "PLAY_CARD",
			payload = {
				hand_index = 1,
				selected_targets = {
					{ object_type = "card", owner = "black", hand_index = 3 },
					{ object_type = "card", owner = "black", hand_index = 4 },
				},
			},
		})

		assert.is_true(result.ok)
		assert.are.equal(1, black.resources.money)
		assert.are.equal(1, #black.cards.hand.ids)
		assert.are.equal("card_point_tap", black.cards.hand.ids[1])
		assert.are.equal(3, #black.cards.discard.ids)
		assert.are.same(
			{ "card_big_mult", "card_small_mult", "card_money_discard_2" },
			black.cards.discard.ids
		)
	end)
end)
