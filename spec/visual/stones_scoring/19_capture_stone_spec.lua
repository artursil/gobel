--- Visual spec: capture_stone (OBJECTS.md #19).
---
--- Stone under test: capture_stone
--- Captures one enemy stone with 0 liberties on placement, regardless of surrounding colors.
--- Opponent cannot recapture on the captured cell for 1 round when capture_stone removed
--- a stone in a mixed black/white surround (capture cooldown). No cooldown in captor-only surround.
--- If multiple targets at 0 liberties, one is selected at random.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	C = { color = config.STONE_BLACK, kind = "capture_stone" },
	c = { color = config.STONE_WHITE, kind = "capture_stone" },
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
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_board_cell_empty = test_helper.assert_board_cell_empty
local assert_legal_player_move_with_stone = test_helper.assert_legal_player_move_with_stone
local assert_illegal_player_move_with_stone = test_helper.assert_illegal_player_move_with_stone
local assert_cell_blocked = test_helper.assert_cell_blocked
local assert_cell_unblocked = test_helper.assert_cell_unblocked
local assert_territory_ascii = test_helper.assert_territory_ascii

local S = P.stone

describe("capture_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "capture_stone" }, "capture_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("basic capture — zero liberties required", function()
		it("enemy stone fully surrounded has 0 liberties, capture_stone removes it and awards bonus", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "capture bonus awarded")
			assert_board_cell_empty(g, 5, 5, "captured white removed from board")
		end)

		it("enemy with 1 liberty remaining is NOT captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W . . . .",
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
				". . . . B . . . .",
				". . . B W . . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_board_stone_present(g, 5, 5, "white stone still has 1 liberty, not captured")
			assert_player_points_unchanged(g, "black", snap, "no bonus when target has remaining liberties")
		end)

		it("no enemy on board means no capture and no bonus", function()
			set_hand(g, "black", { "capture_stone" })
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
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_unchanged(g, "black", snap, "empty board no capture no bonus")
		end)

		it("enemy surrounded by mix of black and white stones still captured at 0 liberties", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "mixed surround still captures at 0 liberties")
			assert_board_cell_empty(g, 5, 5, "white removed despite mixed surrounding colors")
		end)
	end)

	describe("corner and edge captures", function()
		it("corner stone at (1,1) with 0 liberties is captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				"W W . . . . . . .",
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
				"W W . . . . . . .",
				"C . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "corner capture bonus")
			assert_board_cell_empty(g, 1, 1, "corner white captured")
		end)

		it("edge stone at (1,5) with 0 liberties is captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . W W B . . .",
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
				". . . W W B . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "edge capture bonus")
			assert_board_cell_empty(g, 1, 5, "edge white captured")
		end)

		it("bottom-right corner stone at (9,9) with 0 liberties is captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . W W",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . C",
				". . . . . . . W W",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "bottom-right corner capture bonus")
			assert_board_cell_empty(g, 9, 9, "bottom-right corner white captured")
		end)
	end)

	describe("capture cooldown — opponent cannot recapture immediately", function()
		it("opponent cannot place on captured cell for 1 round", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_board_cell_empty(g, 5, 5, "white captured and removed")
			assert_cell_blocked(g, 5, 5, "captured cell blocked for opponent")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "opponent cannot immediately recapture")
		end)

		it("capturing player CAN place on captured cell immediately", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_board_cell_empty(g, 5, 5, "white captured")
			set_hand(g, "black", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 5, 5, "captor can place on captured cell immediately")
		end)

		it("cooldown expires after 1 round, opponent can then place on captured cell", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_cell_blocked(g, 5, 5, "still blocked immediately after capture")
			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "cooldown expired after 1 round")
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "opponent places on captured cell after cooldown")
		end)
	end)

	describe("multi-round recapture scenario", function()
		it("mixed surround: opponent places on captured cell after cooldown expires", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_board_cell_empty(g, 5, 5, "white captured round 1")
			assert_cell_blocked(g, 5, 5, "mixed-surround capture triggers cooldown")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "blocked during cooldown")

			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "cooldown expired")
			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_board_stone_present(g, 5, 5, "white recaptured the cell after cooldown")
		end)

		it("captor-only surround: no cooldown and sealed pocket stays illegal for opponent", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_board_cell_empty(g, 5, 5, "white captured in black-only surround")
			assert_cell_unblocked(g, 5, 5, "no cooldown when only captor stones surround")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "sealed pocket illegal even without cooldown")

			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "still no cooldown after advance")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "sealed pocket still illegal after advance")
		end)

		it("two mixed-surround captures on different cells get independent cooldowns", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . W . .",
				". . . B W . B W .",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . W . .",
				". . . B W C B W .",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_board_cell_empty(g, 5, 5, "first white captured at (5,5)")
			assert_cell_blocked(g, 5, 5, "first capture cell blocked")
			assert_cell_unblocked(g, 8, 5, "second pocket not on cooldown yet")
			test_helper.assert_board_stone_present(g, 8, 5, "second white still on board")

			set_hand(g, "black", { "capture_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . W . .",
				". . . B W C B W C",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_board_cell_empty(g, 8, 5, "second white captured at (8,5)")
			assert_cell_blocked(g, 5, 5, "first capture cooldown still active")
			assert_cell_blocked(g, 8, 5, "second capture cell blocked")

			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "first capture cooldown expired")
			assert_cell_unblocked(g, 8, 5, "second capture cooldown expired")

			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . W . .",
				". . . B W C B W C",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_board_stone_present(g, 5, 5, "white placed back on first captured cell")
			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . W . .",
				". . . B W W B W C",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_board_stone_present(g, 8, 5, "white placed back on second captured cell")
		end)
	end)

	describe("multiple targets — random selection", function()
		it("two enemies at 0 liberties, RNG picks first: only one captured", function()
			test_helper.set_rng_stream(g, "capture_stone", test_helper.rng_always_one)
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . B . . . B . .",
				". B W B . B W B .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . B . . . B . .",
				". B W B . B W B .",
				". . B . . . B . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "only one capture bonus even with two targets")

			local w1_empty = not test_helper.is_board_cell_occupied(g, 3, 3)
			local w2_empty = not test_helper.is_board_cell_occupied(g, 3, 7)
			assert.is_true(w1_empty or w2_empty, "at least one white captured")
			assert.is_false(w1_empty and w2_empty, "only one white captured, not both")
		end)
	end)

	describe("white capture_stone symmetry", function()
		it("white capture_stone captures black stone at 0 liberties and awards white bonus", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . W B . . . .",
				". . . . W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "white")

			test_helper.place_stone_for(g, "white", "capture_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . W B c . . .",
				". . . . W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "white", snap, expected_delta, "white capture_stone bonus awarded")
			assert_board_cell_empty(g, 5, 5, "black stone captured by white")
		end)

		it("white capture_stone cooldown blocks black from recapturing", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . W B . . . .",
				". . . . W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.place_stone_for(g, "white", "capture_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . W B c . . .",
				". . . . W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_board_cell_empty(g, 5, 5, "black captured by white")
			assert_cell_blocked(g, 5, 5, "captured cell blocked for black")
			assert_illegal_player_move_with_stone(g, "black", "stone_basic", 5, 5, "black cannot recapture immediately")

			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "cooldown expired")
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 5, 5, "black recaptures after cooldown")
		end)
	end)

	describe("enclosure scenarios — captures inside enclosed territory", function()
		it("enemy inside own small enclosure with 0 liberties is captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B W B . . .",
				". . . B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B W B . . .",
				". . . B B C . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "captured inside own enclosure")
			assert_board_cell_empty(g, 5, 5, "enclosed white removed")
		end)

		it("enemy inside opponent enclosure (black stone inside white fence) at 0 liberties captured", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "white")

			test_helper.place_stone_for(g, "white", "capture_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W W c . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "white", snap, expected_delta, "white captures black inside white enclosure")
			assert_board_cell_empty(g, 5, 5, "black removed from inside white fence")
		end)

		it("two separate enclosures each with a capturable enemy", function()
			test_helper.set_rng_stream(g, "capture_stone", test_helper.rng_always_one)
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				"B B B . . . . . .",
				"B W B . . . . . .",
				"B B . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . B B B",
				". . . . . . B W B",
				". . . . . . B B .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				"B B B . . . . . .",
				"B W B . . . . . .",
				"B B C . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . B B B",
				". . . . . . B W B",
				". . . . . . B B .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "only one capture even with two enclosed enemies at 0 liberties")
		end)

		it("nested enclosure: enemy inside inner enclosure at 0 liberties is captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". B B B B B B . .",
				". B . . . . B . .",
				". B . B B B B . .",
				". B . B W B . . .",
				". B . B B . . . .",
				". B . . . . B . .",
				". B B B B B B . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". B B B B B B . .",
				". B . . . . B . .",
				". B . B B B B . .",
				". B . B W B . . .",
				". B . B B C . . .",
				". B . . . . B . .",
				". B B B B B B . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "inner nested enclosure capture bonus")
			assert_board_cell_empty(g, 5, 5, "white removed from inner enclosure")
		end)

		it("opponent enclosure nested inside own enclosure: capture enemy at boundary", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				"B B B B B B B B B",
				"B . . . . . . . B",
				"B . W W W W W . B",
				"B . W . . . W . B",
				"B . W . B . W . B",
				"B . W . . . W . B",
				"B . W W W W W . B",
				"B . . . . . . . B",
				"B B B B B B B B B",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				"B B B B B B B B B",
				"B . . . . . . . B",
				"B . W W W W W . B",
				"B . W . B . W . B",
				"B . W B B . W . B",
				"B . W . B . W . B",
				"B . W W W W W . B",
				"B . . . . . . . B",
				"B B B B B B B B B",
			})

			assert_player_points_unchanged(g, "black", snap, "no enemy at 0 liberties inside nested opponent enclosure")
		end)

		it("board-edge enclosure: enemy along edge with 0 liberties is captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				"B B B B B . . . .",
				"B . . . B . . . .",
				"B . W . B . . . .",
				"B . B . B . . . .",
				"B B B B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				"B B B B B . . . .",
				"B . . . B . . . .",
				"B C W . B . . . .",
				"B . B . B . . . .",
				"B B B B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "edge enclosure capture bonus")
			assert_board_cell_empty(g, 3, 3, "white inside edge enclosure captured")
		end)

		it("top-edge enclosure: enemy pinned against top wall with 0 liberties", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . B W B . . . .",
				". . B B . . . . .",
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
				". . B W B . . . .",
				". . B B C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "top-edge pinned capture bonus")
			assert_board_cell_empty(g, 1, 4, "white pinned at top edge captured")
		end)
	end)

	describe("territory impact after capture", function()
		it("capturing enemy inside enclosure flips territory to captor", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B W B . . .",
				". . . B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B W B . . .",
				". . . B B C . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_board_cell_empty(g, 5, 5, "white removed from enclosure")
			assert_territory_ascii(g, {
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b B B B b b b",
				"b b b B b B b b b",
				"b b b B B C b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
			}, "enclosure interior now fully black territory after capture")
		end)
	end)

	describe("capture does NOT trigger on already-placed stones", function()
		it("enemy reaches 0 liberties after opponent places, but no capture_stone was placed this turn", function()
			set_hand(g, "black", { "stone_basic" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W B . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_board_stone_present(g, 5, 5, "regular stone does not trigger capture effect")
		end)
	end)

	describe("placement-only trigger", function()
		it("capture_stone already on board does not re-trigger capture on later rounds", function()
			set_hand(g, "black", { "capture_stone" })
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
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			set_hand(g, "black", { "stone_basic" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B W . . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			set_hand(g, "black", { "stone_basic" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W B . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local snap = player_score_snapshot(g, "black")
			test_helper.advance_rounds(g, 1)
			assert_player_points_unchanged(g, "black", snap, "existing capture_stone on board does not re-trigger capture")
			test_helper.assert_board_stone_present(g, 4, 5, "W(4,5) survives — capture not re-triggered")
		end)
	end)

	describe("occupied cell rejection", function()
		it("cannot place capture_stone on an occupied cell", function()
			set_hand(g, "black", { "capture_stone" })
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

			assert_illegal_player_move_with_stone(g, "black", "capture_stone", 5, 5, "occupied cell rejects capture_stone")
		end)
	end)

	describe("prisoners tracking", function()
		it("successful capture increments prisoner count", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local prisoners_before = g.players.black.prisoners or 0

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert.is_true(
				(g.players.black.prisoners or 0) >= prisoners_before + 1,
				"prisoner counter incremented after capture"
			)
		end)
	end)

	describe("complex multi-round enclosure warfare", function()
		it("capture inside large enclosure, opponent retakes after cooldown, second capture stone finishes them", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				"B B B B B . . . .",
				"B . . . B . . . .",
				"B . . W B . . . .",
				"B . B . B . . . .",
				"B B B B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				"B B B B B . . . .",
				"B . . . B . . . .",
				"B C . W B . . . .",
				"B . B . B . . . .",
				"B B B B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "first capture inside large enclosure")
			assert_board_cell_empty(g, 3, 4, "white removed from inside enclosure")
			assert_cell_blocked(g, 3, 4, "captured cell blocked for opponent")

			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 3, 4, "cooldown expired")

			test_helper.place_stone_for(g, "white", "stone_basic", {
				"B B B B B . . . .",
				"B . . . B . . . .",
				"B C W . B . . . .",
				"B . B . B . . . .",
				"B B B B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_board_stone_present(g, 3, 3, "white re-entered enclosure after cooldown")

			set_hand(g, "black", { "capture_stone" })
			local snap2 = player_score_snapshot(g, "black")
			place_stone(g, {
				"B B B B B . . . .",
				"B . C . B . . . .",
				"B C W . B . . . .",
				"B . B . B . . . .",
				"B B B B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta2 = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap2, expected_delta2, "second capture bonus after opponent returned")
			assert_board_cell_empty(g, 3, 3, "white captured again inside enclosure")
		end)

		it("opponent fills captured cell after cooldown then gets captured again by new capture_stone in different enclosure", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				"B B B . . . . . .",
				"B W B . . . . . .",
				"B B . . . . B B B",
				". . . . . . B . B",
				". . . . . . B B B",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				"B B B . . . . . .",
				"B W B . . . . . .",
				"B B C . . . . . .",
				". . . . . . . . .",
				". . . . . . B B B",
				". . . . . . B . B",
				". . . . . . B B B",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap, expected_delta, "first enclosure capture")
			assert_board_cell_empty(g, 2, 2, "white removed from first enclosure")

			test_helper.advance_rounds(g, 1)
			test_helper.place_stone_for(g, "white", "stone_basic", {
				"B B B . . . . . .",
				"B W B . . . . . .",
				"B B C . . . . . .",
				". . . . . . . . .",
				". . . . . . B B B",
				". . . . . . B . B",
				". . . . . . B B B",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_board_stone_present(g, 2, 2, "white placed back after cooldown in first enclosure")

			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				"B B B . . . . . .",
				"B W B . . . . . .",
				"B B C . . . . . .",
				". . . . . . . . .",
				". . . . . . B B B",
				". . . . . . B W B",
				". . . . . . B B .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap2 = player_score_snapshot(g, "black")

			place_stone(g, {
				"B B B . . . . . .",
				"B W B . . . . . .",
				"B B C . . . . . .",
				". . . . . . . . .",
				". . . . . . B B B",
				". . . . . . B W B",
				". . . . . . B B C",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta2 = S.capture_stone_bonus_points
			assert_player_points_delta(g, "black", snap2, expected_delta2, "second enclosure capture bonus")
			assert_board_cell_empty(g, 6, 8, "white captured in second enclosure")
		end)
	end)
end)
