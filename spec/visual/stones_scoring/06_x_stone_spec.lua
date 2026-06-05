--- Visual spec: x_stone (OBJECTS.md #6).
---
--- Stone under test: x_stone
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	X = { color = config.STONE_BLACK, kind = "x_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_x_mult = test_helper.set_x_mult
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_pattern_stones_in_content = test_helper.assert_pattern_stones_in_content
local assert_player_x_mult = test_helper.assert_player_x_mult
local assert_player_x_mult_delta = test_helper.assert_player_x_mult_delta

describe("x_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"x_stone"}, "x_stone")
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

			local expected_x_mult = P.x_mult_after(snap.x_mult, 1)
			assert_player_x_mult(g, "black", expected_x_mult, "minimal 5-cell X applies one ×2 step")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult increases after one X factor")
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

			local expected_x_mult = P.x_mult_after(snap.x_mult, 3)
			assert_player_x_mult(g, "black", expected_x_mult, "minimal 5-cell X completes with 3 x_stones")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult increases from three X factors")
		end)
	end)

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

			local expected_x_mult = P.x_mult_after(snap.x_mult, 1)
			assert_player_x_mult(g, "black", expected_x_mult, "minimal 5-cell X applies one ×2 step")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult increases after one X factor")
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

			local expected_x_mult = P.x_mult_after(snap.x_mult, 3)
			assert_player_x_mult(g, "black", expected_x_mult, "minimal 5-cell X completes with 3 x_stones")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult increases from three X factors")
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

			local expected_x_mult = P.x_mult_after(snap.x_mult, 1)
			assert_player_x_mult(g, "black", expected_x_mult, "minimal 5-cell X applies one ×2 step")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult increases after one X factor")
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

			local expected_x_mult = P.x_mult_after(snap.x_mult, 1)
			assert_player_x_mult(g, "black", expected_x_mult, "9-cell X applies one X factor from current x_mult")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult delta after 9-cell X")
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

			local expected_x_mult = P.x_mult_after(snap.x_mult, 2)
			assert_player_x_mult(g, "black", expected_x_mult, "9-cell X applies two X factors from current x_mult")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult delta after large X with two x_stones")
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
			local expected_x_mult = P.x_mult_after(snap.x_mult, 3)
			assert_player_x_mult(g, "black", expected_x_mult, "adding a stone completing 2 Xs with three x_stone factors")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult delta after dual X completion")
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
			local expected_x_mult = P.x_mult_after(snap.x_mult, 5)
			assert_player_x_mult(g, "black", expected_x_mult, "adding a stone completing 2 Xs with five x_stone factors")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult delta after dual X with five factors")
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

			local expected_x_mult = P.x_mult_after(snap.x_mult, 3)
			assert_player_x_mult(g, "black", expected_x_mult, "large 13-cell X completed with 3 x_stones")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult delta after 13-cell X")
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

			local expected_x_mult = P.x_mult_after(snap.x_mult, 3)
			assert_player_x_mult(g, "black", expected_x_mult, "large 17-cell X completed with 3 x_stones")
			assert_player_x_mult_delta(g, "black", snap, expected_x_mult - snap.x_mult, "x_mult delta after 17-cell X")
		end)
	end)
end)
