--- Visual spec: delay_reward_stone (OBJECTS.md #18).
---
--- Stone under test: delay_reward_stone
--- Effect: survival timer — on placement registers points_delay_rounds; if the stone
--- still exists when the timer expires, grants points_delay_payout once.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local S = require("spec.parameters_helper").stone

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	P = { color = config.STONE_BLACK, kind = "delay_reward_stone" },
	p = { color = config.STONE_WHITE, kind = "delay_reward_stone" },
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

describe("delay_reward_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "delay_reward_stone" }, "delay_reward_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("delay_reward_stone delayed payout", function()
		it("placement pays zero points immediately", function()
			set_hand(g, "black", { "delay_reward_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap, expected_delta, "no immediate points on placement")
		end)

		it("fresh timer starts at points_delay_rounds", function()
			set_hand(g, "black", { "delay_reward_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_timer = S.points_delay_rounds
			assert_stone_timer(g, 5, 5, expected_timer, "initial delay timer")
		end)

		it("one round elapsed decrements timer by one", function()
			set_hand(g, "black", { "delay_reward_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, 1)
			local expected_timer = S.points_delay_rounds - 1
			assert_stone_timer(g, 5, 5, expected_timer, "timer decremented once")
		end)

		it("one round before expiry pays zero", function()
			set_hand(g, "black", { "delay_reward_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.points_delay_rounds - 1)
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap, expected_delta, "no payout before timer expires")
		end)

		it("timer expiry pays points_delay_payout when stone survives", function()
			set_hand(g, "black", { "delay_reward_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.points_delay_rounds)
			local expected_delta = S.points_delay_payout
			assert_player_points_delta(g, "black", snap, expected_delta, "delayed payout on expiry")
			assert_player_plus_mult_delta(g, "black", snap, 0, "expiry adds points only")
		end)

		it("enemy capture before expiry forfeits payout", function()
			set_hand(g, "black", { "delay_reward_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, 3)
			test_helper.capture_stone_at(g, 5, 5, "black")
			test_helper.advance_rounds(g, S.points_delay_rounds)
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap, expected_delta, "captured stone pays nothing")
		end)

		it("voluntary removal before expiry pays nothing", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			test_helper.capture_stone_at(g, 5, 5, "black")
			test_helper.advance_rounds(g, S.points_delay_rounds)
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap, expected_delta, "removed stone no delayed payout")
		end)

		it("second expiry round never triggers another payout", function()
			set_hand(g, "black", { "delay_reward_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap_after = player_score_snapshot(g, "black")
			test_helper.advance_rounds(g, S.points_delay_rounds)
			test_helper.advance_rounds(g, 2)
			local expected_delta = S.points_delay_payout
			assert_player_points_delta(g, "black", snap_after, expected_delta, "only one expiry payout")
		end)

		it("two stones track independent timers", function()
			set_hand(g, "black", { "delay_reward_stone", "delay_reward_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . P . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.advance_rounds(g, 2)
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . P P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local expected_first_timer = S.points_delay_rounds - 2
			local expected_second_timer = S.points_delay_rounds
			assert_stone_timer(g, 5, 4, expected_first_timer, "first stone older timer")
			assert_stone_timer(g, 5, 5, expected_second_timer, "second stone fresh timer")
		end)

		it("two stones expiring same round each pay points_delay_payout", function()
			set_hand(g, "black", { "delay_reward_stone", "delay_reward_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . P . . . . .",
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
				". . . P P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.advance_rounds(g, S.points_delay_rounds)
			local expected_delta = S.points_delay_payout * 2
			assert_player_points_delta(g, "black", snap, expected_delta, "each surviving stone pays once")
		end)

		it("capture one stone leaves the other eligible for payout", function()
			set_hand(g, "black", { "delay_reward_stone", "delay_reward_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . P . . . . .",
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
				". . . P P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.advance_rounds(g, 2)
			test_helper.capture_stone_at(g, 5, 4, "black")
			test_helper.advance_rounds(g, S.points_delay_rounds)
			local expected_delta = S.points_delay_payout
			assert_player_points_delta(g, "black", snap, expected_delta, "surviving stone still pays on expiry")
		end)

		it("white stone expiry pays white only", function()
			set_board(g, blank_board())
			local white_snap = player_score_snapshot(g, "white")
			local black_snap = player_score_snapshot(g, "black")
			test_helper.place_stone_for(g, "white", "delay_reward_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . p . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.points_delay_rounds)
			local expected_delta = S.points_delay_payout
			assert_player_points_delta(g, "white", white_snap, expected_delta, "white receives own delayed payout")
			local black_expected_delta = 0
			assert_player_points_delta(g, "black", black_snap, black_expected_delta, "black receives no white payout")
		end)

		it("edge placement expiry matches center payout", function()
			set_hand(g, "black", { "delay_reward_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . P",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.points_delay_rounds)
			local expected_delta = S.points_delay_payout
			assert_player_points_delta(g, "black", snap, expected_delta, "edge expiry payout")
		end)

		it("match end before expiry skips unpaid timer", function()
			set_hand(g, "black", { "delay_reward_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.end_match_before_timers(g)
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap, expected_delta, "match end clears unpaid timer")
		end)

		it("staggered expiries pay on different rounds", function()
			set_hand(g, "black", { "delay_reward_stone", "delay_reward_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . P . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.advance_rounds(g, 2)
			test_helper.ensure_actor_turn(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . P P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.advance_rounds(g, S.points_delay_rounds - 2)
			local expected_delta_first = S.points_delay_payout
			assert_player_points_delta(g, "black", snap, expected_delta_first, "older stone pays on its expiry round")
			local snap_mid = player_score_snapshot(g, "black")
			test_helper.advance_rounds(g, 2)
			local expected_delta_second = S.points_delay_payout
			assert_player_points_delta(g, "black", snap_mid, expected_delta_second, "younger stone pays two rounds later")
		end)
	end)
end)
