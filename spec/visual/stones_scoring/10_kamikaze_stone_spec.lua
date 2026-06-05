--- Visual spec: kamikaze_stone (OBJECTS.md #10).
---
--- Stone under test: kamikaze_stone
--- Effect: sacrifice placement — may enter zero-liberty cells, pays kamikaze_points_bonus
--- once, then self-removes from the board.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local S = require("spec.parameters_helper").stone

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	K = { color = config.STONE_BLACK, kind = "kamikaze_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_board_cell_empty = test_helper.assert_board_cell_empty
local assert_legal_player_move_with_stone = test_helper.assert_legal_player_move_with_stone
local assert_illegal_player_move_with_stone = test_helper.assert_illegal_player_move_with_stone

describe("kamikaze_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"kamikaze_stone"}, "kamikaze_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("kamikaze_stone sacrifice placement", function()
		it("kamikaze_stone scenario 1: zero-liberty placement is legal", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_legal_player_move_with_stone(g, "black", "kamikaze_stone", 4, 4, "kamikaze may enter zero-liberty cell")
		end)

		it("kamikaze_stone scenario 2: cell is empty after resolve", function()
			set_hand(g, "black", { "kamikaze_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W K W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_board_cell_empty(g, 4, 4, "kamikaze self-removes from board")
		end)

		it("kamikaze_stone scenario 3: grants configured kamikaze points", function()
			set_hand(g, "black", { "kamikaze_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W K W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.kamikaze_points_bonus
			assert_player_points_delta(g, "black", snap, expected_delta, "kamikaze pays configured bonus")
		end)

		it("kamikaze_stone scenario 4: prisoner increment when self-removal counts", function()
			set_hand(g, "black", { "kamikaze_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local prisoners_before = g.players.white.prisoners or 0

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W K W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			if S.kamikaze_self_removal_counts_as_prisoner then
				assert.are.equal(prisoners_before + 1, g.players.white.prisoners, "white gains prisoner on kamikaze self-removal")
			else
				assert.are.equal(prisoners_before, g.players.white.prisoners, "self-removal does not add prisoner")
			end
		end)

		it("kamikaze_stone scenario 5: edge topology matches center behavior", function()
			set_hand(g, "black", { "kamikaze_stone" })
			set_board(g, {
				"W W W . . . . . .",
				"W . W . . . . . .",
				"W W W . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				"W W W . . . . . .",
				"W K W . . . . . .",
				"W W W . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.kamikaze_points_bonus
			assert_player_points_delta(g, "black", snap, expected_delta, "corner kamikaze same payout")
			assert_board_cell_empty(g, 2, 2, "corner kamikaze self-removes")
		end)

		it("kamikaze_stone scenario 6: occupied cell remains illegal", function()
			set_hand(g, "black", { "kamikaze_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_illegal_player_move_with_stone(g, "black", "kamikaze_stone", 4, 4, "kamikaze cannot overwrite stone")
		end)

		it("kamikaze_stone scenario 7: end_of_turn adds no delayed kamikaze payout", function()
			set_hand(g, "black", { "kamikaze_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W K W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local snap_after = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap_after, expected_delta, "no kamikaze delayed points")
		end)

		it("kamikaze_stone scenario 8: two kamikaze turns each pay once", function()
			set_hand(g, "black", { "kamikaze_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W K W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.finish_turn(g)
			test_helper.pass_turn(g)
			set_hand(g, "black", { "kamikaze_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap2 = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . K . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.kamikaze_points_bonus
			assert_player_points_delta(g, "black", snap2, expected_delta, "second kamikaze pays again")
			expected_delta = S.kamikaze_points_bonus * 2
			assert_player_points_delta(g, "black", snap, expected_delta, "cumulative two kamikaze payouts")
		end)

		it("kamikaze_stone scenario 9: basic stone rejects same zero-liberty cell", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_illegal_player_move_with_stone(g, "black", "stone_basic", 4, 4, "basic cannot use kamikaze liberty override")
		end)

		it("kamikaze_stone scenario 10: kamikaze on open board is legal and pays", function()
			set_hand(g, "black", { "kamikaze_stone" })
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
				". . . . K . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.kamikaze_points_bonus
			assert_player_points_delta(g, "black", snap, expected_delta, "open-board kamikaze still pays")
			assert_board_cell_empty(g, 4, 4, "open-board kamikaze self-removes")
		end)
	end)
end)
