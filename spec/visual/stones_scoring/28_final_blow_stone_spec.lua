--- Visual spec: final_blow_stone (OBJECTS.md #28).
---
--- Stone under test: final_blow_stone
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	P = { color = config.STONE_BLACK, kind = "delay_reward_stone" },
	S = { color = config.STONE_BLACK, kind = "self_destruct_timed_stone" },
	F = { color = config.STONE_BLACK, kind = "final_blow_stone" },
	U = { color = config.STONE_BLACK, kind = "unlimited_upgrades_stone" },
	f = { color = config.STONE_WHITE, kind = "final_blow_stone" },
	R = { color = config.STONE_BLACK, kind = "retrigger_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_stone_instance = test_helper.set_stone_instance
local set_round = test_helper.set_round
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_board_cell_empty = test_helper.assert_board_cell_empty
local assert_stone_timer = test_helper.assert_stone_timer

local S = P.stone

--- @return number
local function points_delay_rounds()
	return S.points_delay_rounds or 7
end

--- @return number
local function points_delay_payout()
	return S.points_delay_payout or P.stone_effect_value("delay_reward_stone", "add_points") or 20
end

--- @return number
local function self_destruct_immediate()
	return S.self_destruct_immediate_points or P.stone_effect_value("self_destruct_timed_stone", "add_points") or 8
end

--- @return number
local function self_destruct_delay()
	return S.self_destruct_delay_rounds or 2
end

--- @return number
local function final_blow_points()
	return S.final_blow_points or P.stone_effect_value("final_blow_stone", "add_points") or 30
end

--- @return number
local function final_blow_plus_mult()
	return S.final_blow_plus_mult or P.stone_effect_value("final_blow_stone", "add_mult") or 10
end

--- @return number
local function final_blow_nonfinal_points()
	return S.final_blow_nonfinal_points or 1
end

--- @param level integer
--- @return number
local function unlimited_level_points(level)
	local per = S.unlimited_upgrades_points_per_level or P.stone_effect_value("unlimited_upgrades_stone", "add_points") or 1
	return per * level
end

--- @param level integer
--- @return number
local function unlimited_level_plus_mult(level)
	local per = S.unlimited_upgrades_plus_mult_per_level or P.stone_effect_value("unlimited_upgrades_stone", "add_mult") or 1
	return per * level
end

local STONE_IDS = {
	"delay_reward_stone",
	"self_destruct_timed_stone",
	"final_blow_stone",
	"unlimited_upgrades_stone",
}

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

describe("final_blow_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"final_blow_stone"}, "final_blow_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("final_blow_stone", function()
		it("final_blow_stone scenario 1: final round pays FINAL_BLOW_POINTS", function()
			test_helper.set_final_round(g, true)
			set_hand(g, "black", { "final_blow_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . F . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, final_blow_points(), "final round points")
		end)

		it("final_blow_stone scenario 2: final round pays FINAL_BLOW_PLUS_MULT", function()
			test_helper.set_final_round(g, true)
			set_hand(g, "black", { "final_blow_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . F . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_plus_mult_delta(g, "black", snap, final_blow_plus_mult(), "final round plus_mult")
		end)

		it("final_blow_stone scenario 3: non-final round pays FINAL_BLOW_NONFINAL_POINTS only", function()
			set_round(g, 2)
			set_hand(g, "black", { "final_blow_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . F . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, final_blow_nonfinal_points(), "fallback points only")
			assert_player_plus_mult_delta(g, "black", snap, 0, "no plus_mult before final round")
		end)

		it("final_blow_stone scenario 4: round before final does not trigger final payout", function()
			test_helper.set_final_round(g, false)
			test_helper.set_rounds_until_final(g, 1)
			set_hand(g, "black", { "final_blow_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . F . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, final_blow_nonfinal_points(), "still non-final payout")
		end)

		it("final_blow_stone scenario 5: final flag true regardless of round index internals", function()
			test_helper.set_final_round(g, true)
			set_round(g, 1)
			set_hand(g, "black", { "final_blow_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . F . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, final_blow_points(), "final flag drives payout")
		end)

		it("final_blow_stone scenario 6: illegal placement pays nothing", function()
			test_helper.set_final_round(g, true)
			set_hand(g, "black", { "final_blow_stone" })
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
			test_helper.assert_illegal_player_move_with_stone(g, "black", "final_blow_stone", 4, 4, "illegal final blow")
			assert_player_points_unchanged(g, "black", snap, "illegal final blow")
		end)

		it("final_blow_stone scenario 7: two final-round placements each pay full package", function()
			test_helper.set_final_round(g, true)
			set_hand(g, "black", { "final_blow_stone", "final_blow_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . F . . . . .",
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
				". . . F F . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap, 2 * final_blow_points(), "two final blows stack points")
			assert_player_plus_mult_delta(g, "black", snap, 2 * final_blow_plus_mult(), "two final blows stack mult")
		end)

		it("final_blow_stone scenario 8: non-final then final placement follows each state", function()
			set_hand(g, "black", { "final_blow_stone", "final_blow_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . F . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap, final_blow_nonfinal_points(), "first on non-final")
			test_helper.set_final_round(g, true)
			local snap2 = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . F F . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap2, final_blow_points(), "second on final round")
		end)

		it("final_blow_stone scenario 9: white final blow pays white", function()
			test_helper.set_final_round(g, true)
			set_hand(g, "white", { "final_blow_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "white")
			test_helper.place_stone_for(g, "white", "final_blow_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . f . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "white", snap, final_blow_points(), "white final blow owner")
		end)

		it("final_blow_stone scenario 10: end_of_turn adds no delayed final_blow payout", function()
			test_helper.set_final_round(g, true)
			set_hand(g, "black", { "final_blow_stone" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . F . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap_after = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "black", snap_after, final_blow_points(), "no second payout at end_of_turn")
		end)
	end)
end)
