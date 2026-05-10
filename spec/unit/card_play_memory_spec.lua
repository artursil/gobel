require("spec.test_helper")

local board = require("board")
local config = require("config")
local game = require("game")
local card_play_memory = require("single_game.resolver.card_play_memory")

describe("card play memory (just_played / played_cards)", function()
	it("flush moves entries to played_cards with turn_number and clears just_played", function()
		local state = { turn_number = 3 }
		card_play_memory.record_just_played_card(state, { type = "card_a", owner = "B" })
		card_play_memory.record_just_played_card(state, {
			type = "card_b",
			owner = "W",
			selected_target = { row = 1, col = 2 },
		})
		assert.are.equal(2, #state.just_played)
		card_play_memory.flush_just_played_to_history(state)
		assert.are.equal(0, #state.just_played)
		assert.are.equal(2, #state.played_cards)
		assert.are.equal("card_a", state.played_cards[1].card_id)
		assert.are.equal("B", state.played_cards[1].owner)
		assert.are.equal(3, state.played_cards[1].turn_number)
		assert.are.equal("card_b", state.played_cards[2].card_id)
		assert.are.equal(1, state.played_cards[2].selected_target.row)
	end)

	it("after resolve, played_cards gains forge play and just_played is empty", function()
		local g = game.new("pvp", "vertical_slice_test")
		g.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic")
		assert.is_true(game.select_board_target(g, 4, 4))
		assert.is_true(game.play_card(g, 2))
		assert.are.equal(0, #g.just_played)
		assert.is_true(#g.played_cards >= 1)
		local last = g.played_cards[#g.played_cards]
		assert.are.equal("card_forge_mark", last.card_id)
		assert.are.equal("B", last.owner)
		assert.are.equal(4, last.selected_target.row)
		assert.are.equal(4, last.selected_target.col)
	end)
end)
