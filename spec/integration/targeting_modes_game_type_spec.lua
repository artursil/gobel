require("spec.test_helper")

local config = require("config")
local game = require("game")
local match_state = require("match_state")

describe("Targeting modes game type", function()
	it("covers attack, heal, and discard-2 flows end to end", function()
		local state = game.new("pvp", "targeting_modes_test")
		local black = match_state.player_for_color(state, "black")
		assert.are.same(
			{ "card_attack_1", "card_heal_1", "card_money_discard_2", "card_point_tap", "card_small_mult" },
			black.cards.hand.ids
		)
		assert.are.equal(config.STONE_BLACK, state.board[4][4].color)
		assert.are.equal(3, state.board[4][4].solidity)
		assert.are.equal(config.STONE_WHITE, state.board[4][5].color)
		assert.are.equal(4, state.board[4][5].solidity)
		assert.is_true(game.play_card(state, 1, {
			{ object_type = "stone", row = 4, col = 5 },
		}))
		assert.are.equal(3, state.board[4][5].solidity)
		assert.is_true(game.play_card(state, 1, {
			{ object_type = "stone", row = 4, col = 4 },
		}))
		assert.are.equal(4, state.board[4][4].solidity)
		local money_before = black.resources.money
		assert.is_true(game.play_card(state, 1, {
			{ object_type = "card", owner = "black", hand_index = 2 },
			{ object_type = "card", owner = "black", hand_index = 3 },
		}))
		assert.are.equal(money_before + 1, black.resources.money)
		assert.are.same({}, black.cards.hand.ids)
		assert.are.equal(5, #black.cards.discard.ids)
	end)
end)
