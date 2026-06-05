--- Visual spec: anti_capture_stone (OBJECTS.md #16).
---
--- Stone under test: anti_capture_stone
--- Grants temporary capture immunity to self + orthogonally connected own stones at placement.
--- Duration: S.anti_capture_duration_rounds. New connections after placement NOT immune.
--- Prevents opponent from making a move that would capture the immune group.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	A = { color = config.STONE_BLACK, kind = "anti_capture_stone" },
	a = { color = config.STONE_WHITE, kind = "anti_capture_stone" },
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
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_legal_player_move_with_stone = test_helper.assert_legal_player_move_with_stone
local assert_illegal_player_move_with_stone = test_helper.assert_illegal_player_move_with_stone
local assert_stone_immune = test_helper.assert_stone_immune
local assert_stone_not_immune = test_helper.assert_stone_not_immune

local S = P.stone

describe("anti_capture_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "anti_capture_stone" }, "anti_capture_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("capture prevention during immunity", function()
		it("opponent cannot fill last liberty of immune group", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W A W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 7, 5, "opponent cannot capture immune group by filling last liberty")
			test_helper.assert_board_stone_present(g, 5, 5, "immune B survives")
			test_helper.assert_board_stone_present(g, 6, 5, "immune A survives")
		end)

		it("after immunity expires, opponent fills last liberty and captures the group", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W A W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.anti_capture_duration_rounds)
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 7, 5, "capture succeeds after expiry")
			test_helper.assert_board_cell_empty(g, 5, 5, "B removed by capture")
			test_helper.assert_board_cell_empty(g, 6, 5, "A removed by capture")
		end)

		it("opponent can place adjacent to immune group if move does not capture", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W . . . .",
				". . . W B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W . . . .",
				". . . W B . . . .",
				". . . . A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 5, 6, "non-capturing adjacent placement allowed")
			test_helper.assert_board_stone_present(g, 5, 5, "immune B still present after non-capturing move")
			test_helper.assert_board_stone_present(g, 6, 5, "immune A still present")
		end)

		it("owner can still place stones near own immune group", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			set_hand(g, "black", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 5, 6, "owner places freely near immune group")
		end)
	end)

	describe("snapshot scope at placement", function()
		it("anti-capture grants immunity to self and orthogonally connected own stones", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B B . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B B . . .",
				". . . . B . . . .",
				". . . . A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_stone_immune(g, 6, 5, S.anti_capture_duration_rounds, "A self immune")
			assert_stone_immune(g, 5, 5, S.anti_capture_duration_rounds, "orthogonal B(5,5) immune")
			assert_stone_immune(g, 4, 5, S.anti_capture_duration_rounds, "chain-connected B(4,5) immune")
			assert_stone_immune(g, 4, 6, S.anti_capture_duration_rounds, "chain-connected B(4,6) immune")
		end)

		it("stone connected AFTER anti-capture placement is NOT immune", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			set_hand(g, "black", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 5, 6, "owner extends group")
			assert_stone_not_immune(g, 5, 6, "post-snapshot stone not in immune scope")
		end)

		it("diagonal own stone is NOT in anti-capture snapshot", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . . . . .",
				". . . . A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_stone_immune(g, 5, 5, S.anti_capture_duration_rounds, "A self immune")
			assert_stone_not_immune(g, 4, 4, "diagonal B not in snapshot")
		end)

		it("large ring group: all connected stones gain immunity from single anti-capture", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B . B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B A B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_stone_immune(g, 5, 5, S.anti_capture_duration_rounds, "A center immune")
			assert_stone_immune(g, 4, 4, S.anti_capture_duration_rounds, "corner B(4,4) immune")
			assert_stone_immune(g, 4, 5, S.anti_capture_duration_rounds, "top B(4,5) immune")
			assert_stone_immune(g, 4, 6, S.anti_capture_duration_rounds, "corner B(4,6) immune")
			assert_stone_immune(g, 5, 4, S.anti_capture_duration_rounds, "left B(5,4) immune")
			assert_stone_immune(g, 5, 6, S.anti_capture_duration_rounds, "right B(5,6) immune")
			assert_stone_immune(g, 6, 4, S.anti_capture_duration_rounds, "corner B(6,4) immune")
			assert_stone_immune(g, 6, 5, S.anti_capture_duration_rounds, "bottom B(6,5) immune")
			assert_stone_immune(g, 6, 6, S.anti_capture_duration_rounds, "corner B(6,6) immune")
		end)

		it("two separate groups: only connected group gets immunity", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . B . . . B . .",
				". . A . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_stone_immune(g, 5, 3, S.anti_capture_duration_rounds, "A immune")
			assert_stone_immune(g, 4, 3, S.anti_capture_duration_rounds, "connected B(4,3) immune")
			assert_stone_not_immune(g, 4, 7, "disconnected B(4,7) not immune")
		end)
	end)

	describe("duration and timer", function()
		it("immunity timer: still immune at D-1 rounds, expired at D rounds", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.anti_capture_duration_rounds - 1)
			assert_stone_immune(g, 4, 5, 1, "B still immune with 1 round left")
			assert_stone_immune(g, 5, 5, 1, "A still immune with 1 round left")

			test_helper.advance_rounds(g, 1)
			assert_stone_not_immune(g, 4, 5, "B no longer immune after full duration")
			assert_stone_not_immune(g, 5, 5, "A no longer immune after full duration")
		end)

		it("overlapping anti-captures on same group keep max duration", function()
			set_hand(g, "black", { "anti_capture_stone", "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . A A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_stone_immune(g, 4, 5, S.anti_capture_duration_rounds, "B keeps max duration from overlap")
			assert_stone_immune(g, 5, 5, S.anti_capture_duration_rounds, "first A keeps max duration")
			assert_stone_immune(g, 5, 4, S.anti_capture_duration_rounds, "second A immune too")
		end)

		it("new anti-capture after first expires grants fresh immunity", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.anti_capture_duration_rounds)
			assert_stone_not_immune(g, 4, 5, "B immunity expired")

			set_hand(g, "black", { "anti_capture_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . A . . . .",
				". . . A . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_stone_immune(g, 4, 5, S.anti_capture_duration_rounds, "B refreshed by new anti-capture")
			assert_stone_immune(g, 6, 4, S.anti_capture_duration_rounds, "new A immune")
		end)
	end)

	describe("source removal and persistence", function()
		it("anti-capture source captured but connected stone keeps immunity timer", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . A . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.capture_stone_at(g, 5, 5, "black")
			test_helper.assert_board_cell_empty(g, 5, 5, "A source removed")
			assert_stone_immune(g, 4, 5, S.anti_capture_duration_rounds, "B retains immunity after source loss")
		end)
	end)

	describe("color boundary", function()
		it("white anti-capture immunizes white group, not nearby black stones", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.place_stone_for(g, "white", "anti_capture_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . W . . .",
				". . . . . a . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_stone_immune(g, 4, 6, S.anti_capture_duration_rounds, "white W immune")
			assert_stone_immune(g, 5, 6, S.anti_capture_duration_rounds, "white a self immune")
			assert_stone_not_immune(g, 4, 4, "black B not affected by white anti-capture")
		end)
	end)

	describe("board edge scenarios", function()
		it("edge group: opponent cannot capture immune group at board edge", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". W . . . . . . .",
				"W B W . . . . . .",
				"W . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". W . . . . . . .",
				"W B W . . . . . .",
				"W A . . . . . . .",
			})
			assert_stone_immune(g, 8, 2, S.anti_capture_duration_rounds, "B immune at edge")
			assert_stone_immune(g, 9, 2, S.anti_capture_duration_rounds, "A immune at edge")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 9, 3, "opponent cannot capture edge immune group")
		end)

		it("after edge immunity expires, opponent captures the edge group", function()
			set_hand(g, "black", { "anti_capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". W . . . . . . .",
				"W B W . . . . . .",
				"W . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". W . . . . . . .",
				"W B W . . . . . .",
				"W A . . . . . . .",
			})
			test_helper.advance_rounds(g, S.anti_capture_duration_rounds)
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 9, 3, "edge capture succeeds after expiry")
			test_helper.assert_board_cell_empty(g, 8, 2, "edge B captured")
			test_helper.assert_board_cell_empty(g, 9, 2, "edge A captured")
		end)
	end)
end)
