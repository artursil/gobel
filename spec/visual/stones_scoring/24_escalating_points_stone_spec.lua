--- Visual spec: escalating_points_stone (OBJECTS.md #24).
---
--- Stone under test: escalating_points_stone
--- Effect: each owner end_of_turn adds eps_round_points to stone bank and owner
--- points; on enemy capture opponent gains eps_capture_multiplier times bank.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local S = require("spec.parameters_helper").stone

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	E = { color = config.STONE_BLACK, kind = "escalating_points_stone" },
	e = { color = config.STONE_WHITE, kind = "escalating_points_stone" },
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
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_stone_stored_value = test_helper.assert_stone_stored_value
local advance_rounds = test_helper.advance_rounds

local function blank_board()
	return {
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
	}
end

describe("escalating_points_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "escalating_points_stone" }, "escalating_points_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("escalating_points_stone per-round accrual and capture transfer", function()
		it("placement pays zero points before first end_of_turn", function()
			set_hand(g, "black", { "escalating_points_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap, expected_delta, "no immediate payout on placement")
			assert_player_plus_mult_delta(g, "black", snap, 0, "placement does not add mult")
			assert_stone_stored_value(g, 5, 5, 0, "bank starts at zero")
		end)

		it("first end_of_turn adds eps_round_points to bank and owner points", function()
			set_hand(g, "black", { "escalating_points_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			advance_rounds(g, 1)
			local expected_bank = S.eps_round_points
			assert_stone_stored_value(g, 5, 5, expected_bank, "bank after one turn")
			local expected_delta = S.eps_round_points
			assert_player_points_delta(g, "black", snap, expected_delta, "owner points gain same round")
			assert_player_plus_mult_delta(g, "black", snap, 0, "accrual adds points only")
		end)

		it("two end_of_turns bank equals two times eps_round_points", function()
			set_hand(g, "black", { "escalating_points_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 2)
			local expected_bank = S.eps_round_points * 2
			assert_stone_stored_value(g, 5, 5, expected_bank, "bank after two turns")
		end)

		it("four end_of_turns bank scales linearly with eps_round_points", function()
			set_hand(g, "black", { "escalating_points_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local rounds = 4
			advance_rounds(g, rounds)
			local expected_bank = S.eps_round_points * rounds
			assert_stone_stored_value(g, 5, 5, expected_bank, "bank scales linearly")
		end)

		it("enemy capture transfers eps_capture_multiplier times bank to opponent", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 2)
			local bank_rounds = 2
			local bank = S.eps_round_points * bank_rounds
			local white_snap = player_score_snapshot(g, "white")
			test_helper.capture_stone_at(g, 5, 5, "white")
			local expected_delta = S.eps_capture_multiplier * bank
			assert_player_points_delta(g, "white", white_snap, expected_delta, "opponent receives capture transfer")
		end)

		it("bank resets to zero after capture", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 1)
			test_helper.capture_stone_at(g, 5, 5, "white")
			local expected_bank = 0
			assert_stone_stored_value(g, 5, 5, expected_bank, "bank cleared on removal")
		end)

		it("self removal resets bank without enemy transfer", function()
			set_hand(g, "black", { "escalating_points_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 1)
			local white_snap = player_score_snapshot(g, "white")
			test_helper.capture_stone_at(g, 5, 5, "black")
			local expected_delta = 0
			assert_player_points_delta(g, "white", white_snap, expected_delta, "no enemy transfer on self removal")
			local expected_bank = 0
			assert_stone_stored_value(g, 5, 5, expected_bank, "bank reset on self removal")
		end)

		it("capturing one stone transfers only that stone bank", function()
			set_hand(g, "black", { "escalating_points_stone", "escalating_points_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . E . . . . .",
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
				". . . E E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local accrual_rounds = 3
			advance_rounds(g, accrual_rounds)
			local captured_bank = S.eps_round_points * accrual_rounds
			local white_snap = player_score_snapshot(g, "white")
			test_helper.capture_stone_at(g, 5, 4, "white")
			local expected_delta = S.eps_capture_multiplier * captured_bank
			assert_player_points_delta(g, "white", white_snap, expected_delta, "only captured stone bank transfers")
		end)

		it("surviving stone bank unchanged when sibling captured", function()
			set_hand(g, "black", { "escalating_points_stone", "escalating_points_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . E . . . . .",
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
				". . . E E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local accrual_rounds = 3
			advance_rounds(g, accrual_rounds)
			test_helper.capture_stone_at(g, 5, 4, "white")
			local expected_bank = S.eps_round_points * accrual_rounds
			assert_stone_stored_value(g, 5, 5, expected_bank, "surviving stone keeps full bank")
		end)

		it("owner keeps points already earned when stone is captured", function()
			set_hand(g, "black", { "escalating_points_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			local accrual_rounds = 2
			advance_rounds(g, accrual_rounds)
			test_helper.capture_stone_at(g, 5, 5, "white")
			local expected_delta = S.eps_round_points * accrual_rounds
			assert_player_points_delta(g, "black", snap, expected_delta, "owner keeps prior round points")
		end)

		it("no further accrual after stone is captured", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 2)
			test_helper.capture_stone_at(g, 5, 5, "white")
			local white_snap = player_score_snapshot(g, "white")
			advance_rounds(g, 1)
			local expected_delta = 0
			assert_player_points_delta(g, "white", white_snap, expected_delta, "captured stone stops accruing")
		end)

		it("white stone accrues eps_round_points for white only", function()
			set_board(g, blank_board())
			test_helper.place_stone_for(g, "white", "escalating_points_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . e . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local white_snap = player_score_snapshot(g, "white")
			local black_snap = player_score_snapshot(g, "black")
			advance_rounds(g, 1)
			local expected_delta = S.eps_round_points
			assert_player_points_delta(g, "white", white_snap, expected_delta, "white receives round accrual")
			local black_expected_delta = 0
			assert_player_points_delta(g, "black", black_snap, black_expected_delta, "black receives no white accrual")
		end)

		it("black capture of white stone transfers bank to black", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . e . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local accrual_rounds = 2
			advance_rounds(g, accrual_rounds)
			local bank = S.eps_round_points * accrual_rounds
			local black_snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			local expected_delta = S.eps_capture_multiplier * bank
			assert_player_points_delta(g, "black", black_snap, expected_delta, "capturer receives white stone bank")
		end)

		it("illegal occupied placement pays nothing", function()
			set_hand(g, "black", { "escalating_points_stone" })
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
			local snap = player_score_snapshot(g, "black")
			test_helper.assert_illegal_player_move_with_stone(g, "black", "escalating_points_stone", 5, 5, "occupied rejects escalating points")
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap, expected_delta, "illegal move no points")
		end)

		it("match end leaves bank without capture transfer", function()
			set_hand(g, "black", { "escalating_points_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 1)
			local expected_bank = S.eps_round_points
			local white_snap = player_score_snapshot(g, "white")
			test_helper.end_match_before_timers(g)
			local expected_delta = 0
			assert_player_points_delta(g, "white", white_snap, expected_delta, "no transfer without capture")
			assert_stone_stored_value(g, 5, 5, expected_bank, "bank remains until capture")
		end)

		it("two placements each accrue eps_round_points independently", function()
			set_hand(g, "black", { "escalating_points_stone", "escalating_points_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . E . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.ensure_actor_turn(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . E E . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local snap = player_score_snapshot(g, "black")
			advance_rounds(g, 1)
			local expected_delta = S.eps_round_points * 2
			assert_player_points_delta(g, "black", snap, expected_delta, "each stone pays one round accrual")
		end)
	end)
end)
