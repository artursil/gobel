--- Visual spec: plus_stone (OBJECTS.md #7).
---
--- Stone under test: plus_stone
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	X = { color = config.STONE_BLACK, kind = "x_stone" },
	P = { color = config.STONE_BLACK, kind = "plus_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_mult = test_helper.set_mult
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_pattern_stones_in_content = test_helper.assert_pattern_stones_in_content
local assert_player_x_mult = test_helper.assert_player_x_mult
local assert_player_x_mult_unchanged = test_helper.assert_player_x_mult_unchanged
local assert_player_plus_mult = test_helper.assert_player_plus_mult
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged

describe("plus_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"plus_stone"}, "plus_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 1)
			assert_player_plus_mult(g, "black", expected_plus_mult, "minimal 5-cell plus adds bonus for one plus_stone")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after minimal plus")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 3)
			assert_player_plus_mult(g, "black", expected_plus_mult, "minimal 5-cell plus with 3 plus_stones")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after 3 plus_stones")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 1)
			assert_player_plus_mult(g, "black", expected_plus_mult, "minimal 5-cell plus adds bonus for one plus_stone")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after minimal plus")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 3)
			assert_player_plus_mult(g, "black", expected_plus_mult, "minimal 5-cell plus with 3 plus_stones")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after 3 plus_stones")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 1)
			assert_player_plus_mult(g, "black", expected_plus_mult, "basic stone completing plus adds bonus for one plus_stone on board")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta from basic completing plus")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 1)
			assert_player_plus_mult(g, "black", expected_plus_mult, "9-cell plus adds bonus for one plus_stone")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after 9-cell plus")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 2)
			assert_player_plus_mult(g, "black", expected_plus_mult, "9-cell plus with two plus_stones")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after 9-cell plus with two plus_stones")
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

			assert_player_plus_mult(g, "black", snap.plus_mult, "adding a stone not completing the plus does not change plus_mult")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 3)
			assert_player_plus_mult(g, "black", expected_plus_mult, "completing 2 pluses with 3 plus_stones")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after dual plus with 3 plus_stones")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 5)
			assert_player_plus_mult(g, "black", expected_plus_mult, "completing 2 pluses with 5 plus_stone bonuses")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after dual plus with five bonuses")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 3)
			assert_player_plus_mult(g, "black", expected_plus_mult, "creating 2 pluses with 3 plus_stones")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after mixed plus sizes")
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

			local expected_plus_mult = P.plus_mult_after(snap.plus_mult, 3)
			assert_player_plus_mult(g, "black", expected_plus_mult, "9-cell plus completed with 3 plus_stones")
			assert_player_plus_mult_delta(g, "black", snap, expected_plus_mult - snap.plus_mult, "plus_mult delta after completing large plus")
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

			assert_player_x_mult(g, "black", P.base_x_mult(), "lonely x_stone does not form an X pattern")
			assert_player_x_mult_unchanged(g, "black", snap, "x_mult unchanged without completed X")
			assert_player_points_unchanged(g, "black", snap, "points unchanged for x_stone placement")
		end)
	end)
end)
