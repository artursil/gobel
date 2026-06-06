--- Visual spec: blockade_stone (OBJECTS.md #13).
---
--- Stone under test: blockade_stone
--- Blocks OPPONENT placement on orthogonal empty neighbors for S.blockade_duration_rounds.
--- Owner can still place freely on those cells.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	K = { color = config.STONE_BLACK, kind = "blockade_stone" },
	k = { color = config.STONE_WHITE, kind = "blockade_stone" },
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
local assert_cell_blocked = test_helper.assert_cell_blocked
local assert_cell_unblocked = test_helper.assert_cell_unblocked

local S = P.stone

describe("blockade_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "blockade_stone" }, "blockade_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("opponent blocked, owner free", function()
		it("place blockade at center, 4 orthogonal neighbors blocked, diagonals free", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W . W . . .",
				". . . . . . . . .",
				". . . . K . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_cell_blocked(g, 4, 5, "above blocked")
			assert_cell_blocked(g, 6, 5, "below blocked")
			assert_cell_blocked(g, 5, 4, "left blocked")
			assert_cell_blocked(g, 5, 6, "right blocked")
			assert_cell_unblocked(g, 4, 4, "top-left diagonal free")
			assert_cell_unblocked(g, 4, 6, "top-right diagonal free")
			assert_cell_unblocked(g, 6, 4, "bottom-left diagonal free")
			assert_cell_unblocked(g, 6, 6, "bottom-right diagonal free")
		end)

		it("white cannot place stone_basic on any black-blockade-blocked cell", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . W . W . . .",
				". . . . K . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 4, 5, "opponent blocked above")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 6, 5, "opponent blocked below")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 4, "opponent blocked left")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 6, "opponent blocked right")
		end)

		it("black (owner) can still place on cells adjacent to own blockade", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . B . . .",
				". . . . K . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			set_hand(g, "black", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 5, 4, "owner places left of own blockade")
		end)

		it("opponent cannot place any stone type on blocked cell including special stones", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . K . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 4, "basic rejected on blocked cell")
			assert_illegal_player_move_with_stone(g, "white", "blockade_stone", 5, 4, "blockade_stone rejected on blocked cell")
			assert_illegal_player_move_with_stone(g, "white", "kamikaze_stone", 5, 4, "kamikaze_stone rejected on blocked cell")
		end)

		it("blockade next to opponent stone does not remove existing stone", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
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
				". . . . W . . . .",
				". . . . K . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_board_stone_present(g, 4, 5, "adjacent opponent stone not removed by blockade")
		end)
	end)

	describe("duration and expiry", function()
		it("blockade still active one round before expiry, opponent still rejected", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B . B . . .",
				". . . B K B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.blockade_duration_rounds - 1)
			assert_cell_blocked(g, 4, 5, "still blocked before expiry")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 4, 5, "opponent still rejected before expiry")
		end)

		it("blockade expires exactly at BLOCKADE_DURATION_ROUNDS, opponent can place again", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . K . . . .",
				". . . W . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.blockade_duration_rounds)
			assert_cell_unblocked(g, 4, 5, "above expired")
			assert_cell_unblocked(g, 6, 5, "below expired")
			assert_cell_unblocked(g, 5, 4, "left expired")
			assert_cell_unblocked(g, 5, 6, "right expired")
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 5, 4, "opponent free after full duration")
		end)

		it("new blockade after full expiry re-blocks for another full duration", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . W . . . . . .",
				". . . . K . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.blockade_duration_rounds)
			assert_cell_unblocked(g, 5, 4, "first blockade expired on left")

			set_hand(g, "black", { "blockade_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . W K . . . . .",
				". . . . K . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_cell_blocked(g, 4, 4, "new blockade re-blocks previously free cell")
			assert_cell_blocked(g, 3, 5, "new blockade blocks its own neighbors")
		end)
	end)

	describe("edge and corner placement", function()
		it("corner blockade at (1,1) blocks only 2 in-bounds orthogonal neighbors", function()
			set_hand(g, "black", { "blockade_stone" })
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
			place_stone(g, {
				"K . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_cell_blocked(g, 1, 2, "right neighbor blocked")
			assert_cell_blocked(g, 2, 1, "below neighbor blocked")
			assert_cell_unblocked(g, 2, 2, "diagonal not blocked")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 1, 2, "opponent blocked at corner neighbor")
		end)

		it("edge blockade at (1,5) blocks 3 in-bounds neighbors, top out of bounds", function()
			set_hand(g, "black", { "blockade_stone" })
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
			place_stone(g, {
				". . . . K . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_cell_blocked(g, 2, 5, "below blocked")
			assert_cell_blocked(g, 1, 4, "left blocked")
			assert_cell_blocked(g, 1, 6, "right blocked")
			assert_cell_unblocked(g, 2, 4, "diagonal not blocked")
			assert_cell_unblocked(g, 2, 6, "diagonal not blocked")
		end)
	end)

	describe("overlapping blockades", function()
		it("two adjacent blockades placed same turn: shared cell blocked for full duration", function()
			set_hand(g, "black", { "blockade_stone", "blockade_stone" })
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
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . K . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . K . K . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_cell_blocked(g, 5, 5, "shared cell (5,5) blocked by both blockades")
			test_helper.advance_rounds(g, S.blockade_duration_rounds - 1)
			assert_cell_blocked(g, 5, 5, "shared cell still blocked before expiry")
			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "shared cell free after full duration")
		end)
	end)

	describe("source capture and persistence", function()
		it("blockade timer persists even after source stone is captured", function()
			set_hand(g, "black", { "blockade_stone" })
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
			test_helper.capture_stone_at(g, 5, 5, "black")
			test_helper.assert_board_cell_empty(g, 5, 5, "source stone removed")
			test_helper.advance_rounds(g, 1)
			assert_cell_blocked(g, 4, 5, "above still blocked after source captured")
			assert_cell_blocked(g, 5, 4, "left still blocked after source captured")
		end)
	end)

	describe("white blockade symmetry", function()
		it("white blockade blocks black from adjacent cells, white free on own blockade cells", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.place_stone_for(g, "white", "blockade_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . B . . .",
				". . . . k . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_cell_blocked(g, 4, 5, "above blocked for black")
			assert_illegal_player_move_with_stone(g, "black", "stone_basic", 4, 5, "black blocked by white blockade above")
			assert_illegal_player_move_with_stone(g, "black", "stone_basic", 5, 4, "black blocked by white blockade left")
			set_hand(g, "white", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 5, 6, "white (owner) free on own blockade's right cell")
		end)

		it("opposing blockades: cell between them blocked for both players", function()
			set_hand(g, "black", { "blockade_stone" })
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
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . K . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.place_stone_for(g, "white", "blockade_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . K . k . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_cell_blocked(g, 5, 5, "center cell between opposing blockades blocked")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "white blocked by black blockade at center")
			assert_illegal_player_move_with_stone(g, "black", "stone_basic", 5, 5, "black blocked by white blockade at center")
		end)
	end)

	describe("strategic board scenarios", function()
		it("blockade denies key expansion cell in contested area", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . B B . W W . .",
				". . B . . . W . .",
				". . B B . W W . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . B B . W W . .",
				". . B . K . W . .",
				". . B B . W W . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_cell_blocked(g, 4, 5, "gap cell above blockade blocked")
			assert_cell_blocked(g, 5, 6, "gap cell right of blockade blocked")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 6, "white cannot bridge gap toward own group")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 4, 5, "white cannot cut through blockade zone")
			set_hand(g, "black", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 4, 5, "black (owner) can fill gap above own blockade")
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 5, 6, "black (owner) can bridge gap right of own blockade")
		end)

		it("blockade between groups: owner extends freely, opponent stuck for full duration", function()
			set_hand(g, "black", { "blockade_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . W . . .",
				". . . B . W . . .",
				". . . B . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B K W . . .",
				". . . B . W . . .",
				". . . B . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 6, "white can't extend right of blockade")
			set_hand(g, "black", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 5, 6, "black extends right past own blockade")
		end)

		it("white blockade stops black sealing enclosure until duration expires", function()
			set_board(g, {
				". . . . . . . . .",
				". . B B B B . . .",
				". . B . . B . . .",
				". . B . . B . . .",
				". . B B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			set_hand(g, "black", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 5, 5,
				"black can play closing stone at (5,5) before blockade")

			set_hand(g, "white", { "blockade_stone" })
			test_helper.place_stone_for(g, "white", "blockade_stone", {
				". . . . . . . . .",
				". . B B B B . . .",
				". . B . . B . . .",
				". . B . . B . . .",
				". . B B k B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_illegal_player_move_with_stone(g, "black", "stone_basic", 5, 5,
				"black cannot occupy closing intersection — white blockade already there")
			assert_cell_blocked(g, 4, 5, "interior cell above blockade blocked for black")
			assert_cell_blocked(g, 6, 5, "cell below blockade blocked for black")
			set_hand(g, "black", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 3, 4,
				"black still free on interior cell outside blockade zone")

			test_helper.advance_rounds(g, S.blockade_duration_rounds - 1)
			assert_cell_blocked(g, 4, 5, "neighbour cells still blocked one round before expiry")
			assert_illegal_player_move_with_stone(g, "black", "stone_basic", 5, 5,
				"closing intersection still white-occupied before expiry")

			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 4, 5, "interior above blockade opens after full duration")
			assert_cell_unblocked(g, 6, 5, "cell below blockade opens after full duration")
			assert_illegal_player_move_with_stone(g, "black", "stone_basic", 5, 5,
				"closing intersection still white-occupied after blockade expires")
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 4, 5,
				"black regains interior access once neighbour block expires")
		end)
	end)
end)
