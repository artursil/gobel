require("spec.test_helper")

local config = require("config")
local game = require("game")
local match_state = require("match_state")
local rules = require("rules")

local function first_legal_move(state, stone_color, stone_id)
	local legal_moves = rules.all_legal_moves(state.board, stone_color, state.ko_ban, stone_id)
	return legal_moves[1]
end

describe("temporary stance turn ownership", function()
	it("applies once on black move and not on white move", function()
		local state = game.new("pvp", "temporary_stance_test")
		local black = match_state.player_for_color(state, "black")
		local white = match_state.player_for_color(state, "white")

		black.cards.hand.ids = { "card_focus_stance" }
		black.energy = 10

		assert.is_true(game.play_card(state, 1))
		assert.are.equal(1, #state.temporary_stances)

		local black_stone = black.stones.selected_stone or black.stones.playable_stones[1]
		local black_move = first_legal_move(state, config.STONE_BLACK, black_stone)
		local black_points_before = black.score.points or 0
		assert.is_true(game.player_move(state, black_move[1], black_move[2]))
		require("spec.test_helper").finish_ui_animations_for_turn(state)
		local black_points_after_black_move = black.score.points or 0
		assert.is_true(black_points_after_black_move - black_points_before >= 5)
		assert.are.equal(2, state.temporary_stances[1].duration.remaining_rounds)

		local black_points_before_white_move = black.score.points or 0
		local white_stone = white.stones.selected_stone or white.stones.playable_stones[1]
		local white_move = first_legal_move(state, config.STONE_WHITE, white_stone)
		assert.is_true(game.player_move(state, white_move[1], white_move[2]))
		local black_points_after_white_move = black.score.points or 0
		require("spec.test_helper").finish_ui_animations_for_turn(state)
		assert.is_true(
			black_points_after_white_move - black_points_before_white_move < 5,
			"temporary stance points must not apply on opponent turn"
		)
		assert.are.equal(2, state.temporary_stances[1].duration.remaining_rounds)
	end)
end)
