--- Visual spec: self_destruct_timed_stone (OBJECTS.md #21).
---
--- Stone under test: self_destruct_timed_stone
--- Effect: on placement adds self_destruct_immediate_points and starts
--- self_destruct_delay_rounds removal timer; on expiry the stone leaves the board
--- with no additional payout.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local S = require("spec.parameters_helper").stone

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	S = { color = config.STONE_BLACK, kind = "self_destruct_timed_stone" },
	s = { color = config.STONE_WHITE, kind = "self_destruct_timed_stone" },
	R = { color = config.STONE_BLACK, kind = "retrigger_stone" },
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
local assert_board_cell_empty = test_helper.assert_board_cell_empty
local assert_stone_timer = test_helper.assert_stone_timer

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

describe("self_destruct_timed_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "self_destruct_timed_stone" }, "self_destruct_timed_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("self_destruct_timed_stone immediate points and removal timer", function()
		it("placement pays self_destruct_immediate_points", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = S.self_destruct_immediate_points
			assert_player_points_delta(g, "black", snap, expected_delta, "immediate points on placement")
			assert_player_plus_mult_delta(g, "black", snap, 0, "placement adds points only")
		end)

		it("fresh timer starts at self_destruct_delay_rounds", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_timer = S.self_destruct_delay_rounds
			assert_stone_timer(g, 5, 5, expected_timer, "removal timer start")
		end)

		it("one round elapsed decrements timer by one", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, 1)
			local expected_timer = S.self_destruct_delay_rounds - 1
			assert_stone_timer(g, 5, 5, expected_timer, "timer tick")
		end)

		it("one round before expiry leaves stone on board", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.self_destruct_delay_rounds - 1)
			assert_stone_timer(g, 5, 5, 1, "timer not yet expired")
		end)

		it("timer expiry removes stone with no extra points", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap_after = player_score_snapshot(g, "black")
			test_helper.advance_rounds(g, S.self_destruct_delay_rounds)
			assert_board_cell_empty(g, 5, 5, "stone removed on expiry")
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap_after, expected_delta, "no points on removal")
		end)

		it("enemy capture ends at immediate points only", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.capture_stone_at(g, 5, 5, "white")
			test_helper.advance_rounds(g, S.self_destruct_delay_rounds)
			local expected_delta = S.self_destruct_immediate_points
			assert_player_points_delta(g, "black", snap, expected_delta, "capture ends at immediate only")
			assert_board_cell_empty(g, 5, 5, "captured stone gone before expiry")
		end)

		it("voluntary removal before expiry adds no extra points", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap_after = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			test_helper.advance_rounds(g, S.self_destruct_delay_rounds)
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap_after, expected_delta, "voluntary removal adds no extra points")
		end)

		it("two stones track independent removal timers", function()
			set_hand(g, "black", { "self_destruct_timed_stone", "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . S . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.advance_rounds(g, 1)
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . S S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local expected_first_timer = S.self_destruct_delay_rounds - 1
			local expected_second_timer = S.self_destruct_delay_rounds
			assert_stone_timer(g, 5, 4, expected_first_timer, "first self destruct older")
			assert_stone_timer(g, 5, 5, expected_second_timer, "second self destruct fresh")
		end)

		it("two stones expiring same round both leave the board", function()
			set_hand(g, "black", { "self_destruct_timed_stone", "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . S S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.self_destruct_delay_rounds)
			assert_board_cell_empty(g, 5, 4, "first stone removed on expiry")
			assert_board_cell_empty(g, 5, 5, "second stone removed on expiry")
		end)

		it("staggered expiries remove stones on different rounds", function()
			set_hand(g, "black", { "self_destruct_timed_stone", "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . S . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.advance_rounds(g, 1)
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . S S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.advance_rounds(g, S.self_destruct_delay_rounds - 1)
			assert_board_cell_empty(g, 5, 4, "older stone removed first")
			assert_stone_timer(g, 5, 5, 1, "younger stone still on board")
			test_helper.advance_rounds(g, 1)
			assert_board_cell_empty(g, 5, 5, "younger stone removed one round later")
		end)

		it("white placement pays white immediate points only", function()
			set_board(g, blank_board())
			local white_snap = player_score_snapshot(g, "white")
			local black_snap = player_score_snapshot(g, "black")
			test_helper.place_stone_for(g, "white", "self_destruct_timed_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . s . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = S.self_destruct_immediate_points
			assert_player_points_delta(g, "white", white_snap, expected_delta, "white receives immediate points")
			local black_expected_delta = 0
			assert_player_points_delta(g, "black", black_snap, black_expected_delta, "black receives no white payout")
		end)

		it("edge placement expiry removes stone", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . S",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.self_destruct_delay_rounds)
			assert_board_cell_empty(g, 1, 9, "edge stone removed")
		end)

		it("corner placement expiry removes stone", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				"S . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.self_destruct_delay_rounds)
			assert_board_cell_empty(g, 1, 1, "corner stone removed")
		end)

		it(
			"retrigger replays immediate points only",
			pending("retrigger_stone is a stub until issue #31; cross-stone retrigger is out of scope for #20")
		)

		it("illegal occupied placement pays nothing", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
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
			test_helper.assert_illegal_player_move_with_stone(g, "black", "self_destruct_timed_stone", 5, 5, "occupied rejects self destruct")
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap, expected_delta, "illegal move no points")
		end)

		it("match end before expiry adds no extra payout", function()
			set_hand(g, "black", { "self_destruct_timed_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.end_match_before_timers(g)
			local expected_delta = S.self_destruct_immediate_points
			assert_player_points_delta(g, "black", snap, expected_delta, "no extra payout at match end")
		end)

		it("two placements each pay self_destruct_immediate_points once", function()
			set_hand(g, "black", { "self_destruct_timed_stone", "self_destruct_timed_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . S . . . . .",
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
				". . . S S . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local expected_delta = 2 * S.self_destruct_immediate_points
			assert_player_points_delta(g, "black", snap, expected_delta, "each placement pays immediate once")
		end)
	end)
end)
