require("spec.test_helper")

local board = require("board")
local config = require("config")
local content = require("content")
local game = require("game")
local match_state = require("match_state")
local rules = require("rules")

describe("T-051 integration minimal playable loop", function()
	it("runs start -> play card -> select stone -> place -> pass to conclusion", function()
		local g = game.new("pvp")
		local black = match_state.player_for_color(g, "black")
		local white = match_state.player_for_color(g, "white")

		assert.are.equal("black", g.to_play)
		assert.are.equal("MAIN_PHASE", g.phase)
		assert.are.equal(1, g.turn_number)
		assert.are.equal(4, #black.cards.hand.ids)

		local energy_before_card = black.resources.energy_current
		local discard_before = #black.cards.discard.ids
		local card_id = black.cards.hand.ids[1]
		local card_def = content.get_card(card_id)
		local played = game.play_card(g, 1)
		assert.is_true(played)
		assert.are.equal(energy_before_card - card_def.energy_cost, black.resources.energy_current)
		assert.are.equal(discard_before + 1, #black.cards.discard.ids)

		local selection = black.stones.playable_stones[2] or black.stones.playable_stones[1]
		assert.is_true(selection ~= nil)
		local selected = game.select_stone(g, selection)
		assert.is_true(selected)
		assert.are.equal(selection, black.stones.selected_stone)

		local legal_moves = rules.all_legal_moves(g.board, config.STONE_BLACK, g.ko_ban, black.stones.selected_stone)
		local move = legal_moves[1]
		local moved = game.player_move(g, move[1], move[2])
		assert.is_true(moved)
		assert.are.equal("white", g.to_play)
		assert.are.equal(2, g.turn_number)
		assert.is_false(board.is_empty(g.board[move[1]][move[2]]))
		assert.is_true(black.score.total > 0)

		if g.phase == "MAIN_PHASE" then
			game.player_pass(g)
		end
		if g.phase == "MAIN_PHASE" then
			game.player_pass(g)
		end

		assert.is_true(g.ended)
		assert.are.equal("MATCH_END", g.phase)
		assert.are.equal("two_passes", g.end_reason)
		assert.is_true(g.winner == "black" or g.winner == "white" or g.winner == "draw")
		assert.are.equal(0, white.resources.money)
	end)
end)
