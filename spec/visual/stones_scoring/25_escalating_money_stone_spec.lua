--- Visual spec: escalating_money_stone (OBJECTS.md #25).
---
--- Stone under test: escalating_money_stone
--- Effect: each owner end_of_turn adds ems_round_money to owner money and tracks
--- cumulative received; on capture the stone owner pays ems_capture_multiplier times total received.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local S = require("spec.parameters_helper").stone

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	R = { color = config.STONE_BLACK, kind = "escalating_money_stone" },
	r = { color = config.STONE_WHITE, kind = "escalating_money_stone" },
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
local assert_player_money = test_helper.assert_player_money
local assert_player_points_delta = test_helper.assert_player_points_delta
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

describe("escalating_money_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "escalating_money_stone" }, "escalating_money_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("escalating_money_stone per-round accrual and capture penalty", function()
		it("placement pays zero money before first end_of_turn", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "no immediate payout on placement")
			assert_player_points_delta(g, "black", snap, expected_delta, "placement does not add points")
			assert_stone_stored_value(g, 5, 5, 0, "tracked total starts at zero")
		end)

		it("first end_of_turn adds ems_round_money to owner money", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			advance_rounds(g, 1)
			local expected_delta = S.ems_round_money
			assert_player_money(g, "black", snap.money + expected_delta, "owner money gain same round")
			assert_stone_stored_value(g, 5, 5, expected_delta, "tracked total after one turn")
			assert_player_points_delta(g, "black", snap, 0, "accrual adds money only")
		end)

		it("two end_of_turns accumulate two times ems_round_money", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			advance_rounds(g, 2)
			local expected_delta = S.ems_round_money * 2
			assert_player_money(g, "black", snap.money + expected_delta, "two ticks cumulative")
			assert_stone_stored_value(g, 5, 5, expected_delta, "tracked total after two turns")
		end)

		it("four end_of_turns scale linearly with ems_round_money", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			local rounds = 4
			advance_rounds(g, rounds)
			local expected_delta = S.ems_round_money * rounds
			assert_player_money(g, "black", snap.money + expected_delta, "N turn cumulative")
			assert_stone_stored_value(g, 5, 5, expected_delta, "tracked total scales linearly")
		end)

		it("capture charges ems_capture_multiplier times total received from owner", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local accrual_rounds = 2
			advance_rounds(g, accrual_rounds)
			local received = S.ems_round_money * accrual_rounds
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			local expected_penalty = S.ems_capture_multiplier * received
			assert_player_money(g, "black", snap.money - expected_penalty, "capture penalty from cumulative received")
		end)

		it("tracked total resets to zero after capture", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 1)
			test_helper.capture_stone_at(g, 5, 5, "black")
			local expected_total = 0
			assert_stone_stored_value(g, 5, 5, expected_total, "tracked total cleared on removal")
		end)

		it("self removal charges no capture penalty", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 1)
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "self removal no penalty")
		end)

		it("capturing one stone penalizes only that stone cumulative received", function()
			set_hand(g, "black", { "escalating_money_stone", "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . R . . . . .",
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
				". . . R R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local accrual_rounds = 3
			advance_rounds(g, accrual_rounds)
			local captured_received = S.ems_round_money * accrual_rounds
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 4, "black")
			local expected_penalty = S.ems_capture_multiplier * captured_received
			assert_player_money(g, "black", snap.money - expected_penalty, "only captured stone total penalized")
		end)

		it("surviving stone tracked total unchanged when sibling captured", function()
			set_hand(g, "black", { "escalating_money_stone", "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . R . . . . .",
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
				". . . R R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local accrual_rounds = 3
			advance_rounds(g, accrual_rounds)
			test_helper.capture_stone_at(g, 5, 4, "black")
			local expected_total = S.ems_round_money * accrual_rounds
			assert_stone_stored_value(g, 5, 5, expected_total, "surviving stone keeps full tracked total")
		end)

		it("owner net money reflects accrual minus capture penalty", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			local accrual_rounds = 2
			advance_rounds(g, accrual_rounds)
			local received = S.ems_round_money * accrual_rounds
			test_helper.capture_stone_at(g, 5, 5, "black")
			local expected_money = snap.money + received - S.ems_capture_multiplier * received
			assert_player_money(g, "black", expected_money, "earned money minus capture penalty")
		end)

		it("no further accrual after stone is captured", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 2)
			test_helper.capture_stone_at(g, 5, 5, "black")
			local snap = player_score_snapshot(g, "black")
			advance_rounds(g, 1)
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "captured stone stops accruing")
		end)

		it("white stone accrues ems_round_money for white only", function()
			set_board(g, blank_board())
			test_helper.place_stone_for(g, "white", "escalating_money_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . r . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local white_snap = player_score_snapshot(g, "white")
			local black_snap = player_score_snapshot(g, "black")
			advance_rounds(g, 1)
			local expected_delta = S.ems_round_money
			assert_player_money(g, "white", white_snap.money + expected_delta, "white receives round accrual")
			local black_expected_delta = 0
			assert_player_money(g, "black", black_snap.money + black_expected_delta, "black receives no white accrual")
		end)

		it("capture penalty clamps money at global floor", function()
			set_hand(g, "black", { "escalating_money_stone" })
			test_helper.set_money(g, "black", 1)
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local accrual_rounds = 3
			advance_rounds(g, accrual_rounds)
			test_helper.capture_stone_at(g, 5, 5, "black")
			local expected_money = 0
			assert_player_money(g, "black", expected_money, "money clamp at floor")
		end)

		it("ems_capture_multiplier 3 makes penalty triple received", function()
			test_helper.set_stone_parameter(g, "escalating_money_stone", "ems_capture_multiplier", 3)
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local accrual_rounds = 2
			advance_rounds(g, accrual_rounds)
			local received = S.ems_round_money * accrual_rounds
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			local expected_penalty = S.ems_capture_multiplier * received
			assert_player_money(g, "black", snap.money - expected_penalty, "triple penalty")
		end)

		it("illegal occupied placement pays nothing", function()
			set_hand(g, "black", { "escalating_money_stone" })
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
			test_helper.assert_illegal_player_move_with_stone(g, "black", "escalating_money_stone", 5, 5, "occupied rejects escalating money")
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "illegal move no money")
		end)

		it("match end charges no capture penalty without capture", function()
			set_hand(g, "black", { "escalating_money_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			advance_rounds(g, 1)
			local expected_total = S.ems_round_money
			local snap = player_score_snapshot(g, "black")
			test_helper.end_match_before_timers(g)
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "no penalty without capture")
			assert_stone_stored_value(g, 5, 5, expected_total, "tracked total remains until capture")
		end)

		it("two placements each accrue ems_round_money independently", function()
			set_hand(g, "black", { "escalating_money_stone", "escalating_money_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . R . . . . .",
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
				". . . R R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			advance_rounds(g, 1)
			local expected_delta = S.ems_round_money * 2
			assert_player_money(g, "black", snap.money + expected_delta, "each stone pays one round accrual")
		end)
	end)
end)
