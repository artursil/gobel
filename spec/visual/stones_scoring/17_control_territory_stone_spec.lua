--- Visual spec: control_territory_stone (OBJECTS.md #17).
---
--- Payout = mult_control_streak_multiplier * abs(streak) on own territory;
--- penalty on enemy territory (plus_mult floored at 0). Reads territory_control_rounds at placement cell only.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	M = { color = config.STONE_BLACK, kind = "control_territory_stone" },
	m = { color = config.STONE_WHITE, kind = "control_territory_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_board = test_helper.set_board
local set_control = test_helper.set_territory_control_rounds_ascii
local place_stone = test_helper.place_stone
local place_stone_for = test_helper.place_stone_for
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_plus_mult_unchanged = test_helper.assert_player_plus_mult_unchanged
local advance_rounds = test_helper.advance_rounds

local S = P.stone

local EMPTY_BOARD = {
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

describe("control_territory_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "control_territory_stone" }, "control_territory_stone")
		set_board(g, EMPTY_BOARD)
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("black on own +5 cell pays positive plus_mult", function()
		set_hand(g, "black", { "control_territory_stone" })
		set_control(g, {
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +5 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		})
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 5
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . M . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "own +5")
	end)

	it("white on own -4 cell pays positive plus_mult", function()
		set_hand(g, "white", { "control_territory_stone" })
		set_control(g, {
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 -4 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		})
		local snap = player_score_snapshot(g, "white")
		local expected_delta = S.mult_control_streak_multiplier * 4
		place_stone_for(g, "white", "control_territory_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . m . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "white", snap, expected_delta, "own -4")
	end)

	it("black on enemy -3 cell applies penalty", function()
		set_hand(g, "black", { "control_territory_stone" })
		test_helper.set_mult(g, "black", 10)
		set_control(g, {
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 -3 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		})
		local snap = player_score_snapshot(g, "black")
		local expected_delta = -(S.mult_control_streak_multiplier * 3)
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . M . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "enemy -3")
	end)

	it("white on enemy +2 cell applies penalty", function()
		set_hand(g, "white", { "control_territory_stone" })
		test_helper.set_mult(g, "white", 10)
		set_control(g, {
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +2 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		})
		local snap = player_score_snapshot(g, "white")
		local expected_delta = -(S.mult_control_streak_multiplier * 2)
		place_stone_for(g, "white", "control_territory_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . m . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "white", snap, expected_delta, "enemy +2")
	end)

	it("neutral +0 cell pays nothing", function()
		set_hand(g, "black", { "control_territory_stone" })
		set_control(g, {
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . M . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, 0, "neutral +0")
	end)

	it("streak +1 pays mult_control_streak_multiplier", function()
		set_hand(g, "black", { "control_territory_stone" })
		set_control(g, {
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +1 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		})
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 1
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . M . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "boundary +1")
	end)

	it("penalty is floored when plus_mult would go below zero", function()
		set_hand(g, "black", { "control_territory_stone" })
		test_helper.set_mult(g, "black", 2)
		set_control(g, {
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 -5 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . M . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, -2, "floor at 0 from plus_mult 2")
		assert.are.equal(0, test_helper.player_score_snapshot(g, "black").plus_mult)
	end)

	it("one-time trigger: no payout after advance_rounds", function()
		set_hand(g, "black", { "control_territory_stone" })
		set_control(g, {
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +3 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		})
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . M . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap_after = player_score_snapshot(g, "black")
		advance_rounds(g, 3)
		assert_player_plus_mult_unchanged(g, "black", snap_after, "no recurring payout")
	end)

	it("multi-zone board reads only placement cell", function()
		set_hand(g, "black", { "control_territory_stone" })
		set_control(g, {
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +3 +0 +0 +0 -5 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		})
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 3
		place_stone(g, {
			". . . . . . . . .",
			". . M . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "reads +3 only")
	end)
end)
