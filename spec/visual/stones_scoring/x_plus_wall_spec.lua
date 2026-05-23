local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	X = { color = config.STONE_BLACK, kind = "x_stone" },
	P = { color = config.STONE_BLACK, kind = "plus_stone" },
	W = { color = config.STONE_BLACK, kind = "wall" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_energy = test_helper.set_energy
local set_money = test_helper.set_money
local set_cards = test_helper.set_cards
local set_stances = test_helper.set_stances
local set_round = test_helper.set_round
local set_persistent_counter = test_helper.set_persistent_counter
local set_points = test_helper.set_points
local set_mult = test_helper.set_mult
local set_x_mult = test_helper.set_x_mult
local set_board = test_helper.set_board
local play_card = test_helper.play_card
local play_cards = test_helper.play_cards
local place_stone = test_helper.place_stone
local play_card_and_stone = test_helper.play_card_and_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_pattern_stones_in_content = test_helper.assert_pattern_stones_in_content
local assert_player_x_mult = test_helper.assert_player_x_mult
local assert_player_x_mult_delta = test_helper.assert_player_x_mult_delta
local assert_player_x_mult_unchanged = test_helper.assert_player_x_mult_unchanged
local assert_player_plus_mult = test_helper.assert_player_plus_mult
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_plus_mult_unchanged = test_helper.assert_player_plus_mult_unchanged
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_board_stone_modifier_absent = test_helper.assert_board_stone_modifier_absent

describe("x_stone plus_stone wall scoring (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))
	describe("x_stone completes diagonal X and multiplies x_mult", function()
		it("minimal 5-cell X: place x_stone at center, black x_mult becomes 2", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . B . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . X . B . . .",
				". . . . B . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 2, "minimal 5-cell X applies one ×2 step")
			assert_player_x_mult_delta(g, "black", snap, 1, "x_mult increases by 1 after ×2 from base 1")
		end)
		it("minimal 5-cell X: completing the X with 3 x_stones, black x_mult becomes 8", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . X . . . .",
				". . . X . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . X . B . . .",
				". . . . X . . . .",
				". . . X . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 8, "minimal 5-cell X completes with 3 x_stones, black x_mult becomes 8")
			assert_player_x_mult_delta(g, "black", snap, 7, "x_mult increases by 7 from 1 to 8")
		end)
	end)
	describe("any stone completes diagonal X and multiplies x_mult", function()
		it("minimal 5-cell X: place x_stone at center, black x_mult becomes 2", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 2, "minimal 5-cell X applies one ×2 step")
			assert_player_x_mult_delta(g, "black", snap, 1, "x_mult increases by 1 after ×2 from base 1")
		end)


		it("large 9-cell X: place x_stone, black x_mult becomes 4", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 2)
			set_board(g, {
				". . . . . . . . .",
				". . B . . . . . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . B . . . B . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 4, "9-cell X applies two ×2 steps (cumulative ×4)")
			assert_player_x_mult_delta(g, "black", snap, 2, "x_mult increases by 2 from 2 to 4")
		end)
		it("large 9-cell X: complete large X with x_stone, black x_mult becomes 4", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 2)
			set_board(g, {
				". . . . . . . . .",
				". . B . . . . . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 8, "9-cell X applies two ×2 steps twice (cumulative ×8)")
			assert_player_x_mult_delta(g, "black", snap, 6, "x_mult increases by 6 from 6 to 8")
		end)
		it("large 9-cell X: adding a stone not completing the X does not change x_mult", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 6)
			set_board(g, {
				". . . . . . . . .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . B .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 6, "adding a stone not completing the X does not change x_mult")
			assert_player_x_mult_delta(g, "black", snap, 0, "x_mult unchanged without completed X")
		end)
		it("large 9-cell X: adding a stone completing 2 Xs, 3 times x2 is triggered", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 2)
			set_board(g, {
				". . . . . . . . .",
				". . . . B . X . .",
				". . . B . B . . .",
				". . B . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . B . B . X . .",
				". . . B . B . . .",
				". . B . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_x_mult(g, "black", 16, "adding a stone completing 2 Xs, 3 times x2 is triggered")
			assert_player_x_mult_delta(g, "black", snap, 14, "x_mult increases by 14 from 2 to 16")
		end)
		it("large 9-cell X: adding an x_stone completing 2 Xs, 5 times x2 is triggered", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 2)
			set_board(g, {
				". . . . . . . . .",
				". . . . B . X . .",
				". . . B . B . . .",
				". . B . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . X . B . X . .",
				". . . B . B . . .",
				". . B . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_x_mult(g, "black", 64, "adding a stone completing 2 Xs, 5 times x2 is triggered")
			assert_player_x_mult_delta(g, "black", snap, 62, "x_mult increases by 62 from 2 to 64")
		end)
		it("large 13-cell X: completing large X with 3 x_stones, black x_mult becomes 48", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 6)
			set_board(g, {
				". B . . . . . . .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". B . . . . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". B . . . . . X .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". B . . . . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 48, "large 13-cell X completed with 3 x_stones, black x_mult becomes 48")
			assert_player_x_mult_delta(g, "black", snap, 42, "x_mult increases by 42 from 6 to 48")
		end)
		it("large 17-cell X: completing large X with 3 x_stones, black x_mult becomes 384", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 48)
			set_board(g, {
				". . . . . . . . B",
				". B . . . . . X .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". B . . . . . B .",
				"B . . . . . . . B",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				"B . . . . . . . B",
				". B . . . . . X .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". B . . . . . B .",
				"B . . . . . . . B",
			})

			assert_player_x_mult(g, "black", 384, "large 17-cell X completed with 3 x_stones, black x_mult becomes 384")
			assert_player_x_mult_delta(g, "black", snap, 336, "x_mult increases by 336 from 48 to 384")
		end)
	end)

	describe("plus_stone completes orthogonal plus and adds plus_mult", function()
		it("minimal 5-cell plus: place plus_stone at center, black plus_mult becomes 6", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "plus_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . B . B . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . B P B . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 6, "minimal 5-cell plus adds +5 for one plus_stone")
			assert_player_plus_mult_delta(g, "black", snap, 5, "plus_mult increases by 5 from base 1")
		end)
		it("minimal 5-cell plus: completing the plus with 3 plus_stones, black plus_mult becomes 16", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "plus_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . P . . .",
				". . . . P . B . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . P . . .",
				". . . . P P B . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 16, "minimal 5-cell plus with 3 plus_stones adds +15")
			assert_player_plus_mult_delta(g, "black", snap, 15, "plus_mult increases by 15 from 1 to 16")
		end)
	end)
	describe("any stone completes orthogonal plus and adds plus_mult", function()
		it("minimal 5-cell plus: basic stone completes plus with plus_stone on board, black plus_mult becomes 6", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "stone_basic" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . P . B . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . P B B . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 6, "basic stone completing plus adds +5 for one plus_stone on board")
			assert_player_plus_mult_delta(g, "black", snap, 5, "plus_mult increases by 5 from base 1")
		end)

		it("large 9-cell plus: place basic stone, black plus_mult becomes 11", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "stone_basic" })
			set_mult(g, "black", 6)
			set_board(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . B B P B . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . B B P B B .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 11, "9-cell plus adds +5 for one plus_stone")
			assert_player_plus_mult_delta(g, "black", snap, 5, "plus_mult increases by 5 from 6 to 11")
		end)
		it("large 9-cell plus: complete large plus with plus_stone, black plus_mult becomes 16", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "plus_stone" })
			set_mult(g, "black", 6)
			set_board(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . B B P B . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . B B P B P .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 16, "9-cell plus with two plus_stones adds +10")
			assert_player_plus_mult_delta(g, "black", snap, 10, "plus_mult increases by 10 from 6 to 16")
		end)
		it("large 9-cell plus: adding a stone not completing the plus does not change plus_mult", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "stone_basic" })
			set_mult(g, "black", 16)
			set_board(g, {
				". . . . . P . . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . B B P B B .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . B . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . B B P B B .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 16, "adding a stone not completing the plus does not change plus_mult")
			assert_player_plus_mult_delta(g, "black", snap, 0, "plus_mult unchanged without completed plus")
		end)
		it("large 9-cell plus: adding a stone completing 2 pluses, 3 times +5 is triggered", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "stone_basic" })
			set_mult(g, "black", 1)
			set_board(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . B P B . .",
				". . . . . . . . .",
				". . . . B P P . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . B P B . .",
				". . . . . B . . .",
				". . . . B P P . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 16, "completing 2 pluses with 3 plus_stones adds +10")
			assert_player_plus_mult_delta(g, "black", snap, 15, "plus_mult increases by 15 from 1 to 16")
		end)
		it("large 9-cell plus: adding a plus_stone completing 2 pluses, 5 times +5 is triggered", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "plus_stone" })
			set_mult(g, "black", 1)
			set_board(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . B P B . .",
				". . . . . . . . .",
				". . . . B P P . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . B P B . .",
				". . . . . P . . .",
				". . . . B P P . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 26, "completing 2 pluses with 4 plus_stones adds +35")
			assert_player_plus_mult_delta(g, "black", snap, 25, "plus_mult increases by 25 from 1 to 26")
		end)
		it("creating 2 pluses one big one small", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "plus_stone" })
			set_mult(g, "black", 6)
			set_board(g, {
				". . . . B . . . .",
				". . . . B . . . .",
				". . B B P B B . .",
				". . . . B . . . .",
				". . . B . B . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . B . . . .",
				". . . . B . . . .",
				". . B B P B B . .",
				". . . . B . . . .",
				". . . B P B . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 21, "creating 2 pluses one big one small with 3 plus_stones adds +15")
			assert_player_plus_mult_delta(g, "black", snap, 15, "plus_mult increases by 15 from 6 to 21")
		end)
		it("large 9-cell plus: completing large plus with 3 plus_stones, black plus_mult becomes 16", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "plus_stone" })
			set_mult(g, "black", 1)
			set_board(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . P P B B . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . P P B B P .",
				". . . . . B . . .",
				". . . . . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_plus_mult(g, "black", 16, "9-cell plus completed with 3 plus_stones adds +10")
			assert_player_plus_mult_delta(g, "black", snap, 15, "plus_mult increases by 15 from 1 to 16")
		end)
		it("isolated x_stone placement does not change x_mult", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . X . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 1, "lonely x_stone does not form an X pattern")
			assert_player_x_mult_unchanged(g, "black", snap, "x_mult unchanged without completed X")
			assert_player_points_unchanged(g, "black", snap, "points unchanged for x_stone placement")
		end)
	end)

	describe("wall stone connected group points", function()
		it("basic stone beside walls gets only basic +1, not wall bonus", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "stone_basic" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, 1, "only basic stone +1, no wall bonus")
			assert_board_stone_modifier_absent(g, 3, 3, "existing wall at 3,3 has no points bonus")
			assert_board_stone_modifier_absent(g, 3, 4, "existing wall at 3,4 has no points bonus")
		end)

		it("third wall in a row adds no bonus below 5 connected stones", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_unchanged(g, "black", snap, "3 connected walls grant no wall bonus")
		end)

		it("fifth wall in a row adds +5 for 5 connected stones", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . W W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . W W W W W . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, 5, "5 connected walls grant +5")
		end)

		it("wall as 5th stone in mixed group adds +5", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B B B B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W B B B B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, 5, "wall joining 4 basics to 5 connected adds +5")
		end)

		it("tenth connected stone via wall placement adds +10", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B . B B .",
				". . . B B B B B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B W B B .",
				". . . B B B B B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, 10, "10 connected stones grant +10 on wall placement")
		end)

		it("sixth connected wall adds +5 not +10", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . W W W W W . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . W W W W W W .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, 5, "6 connected walls still grant only one +5 block")
		end)
	end)
end)
