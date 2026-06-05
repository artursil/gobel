--- Visual spec: mult_3_rounds_stone (OBJECTS.md #17).
---
--- Stone under test: mult_3_rounds_stone
--- On placement, reads territory_control_rounds at cell.
--- If owner matches control sign (+ = black, - = white),
--- payout = mult_control_streak_multiplier * abs(streak) to plus_mult.
--- Uncontrolled (0) or opponent-controlled → payout = 0. One-time trigger.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	M = { color = config.STONE_BLACK, kind = "mult_3_rounds_stone" },
	m = { color = config.STONE_WHITE, kind = "mult_3_rounds_stone" },
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
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_plus_mult_unchanged = test_helper.assert_player_plus_mult_unchanged
local advance_rounds = test_helper.advance_rounds

local S = P.stone

describe("mult_3_rounds_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "mult_3_rounds_stone" }, "mult_3_rounds_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("black ring enclosure, M at center with streak 3, pays plus_mult", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
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
		test_helper.set_territory_control_rounds(g, 5, 5, 3)
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 3
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B M B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "streak 3 in enclosed cell")
	end)

	it("white U-shape enclosure, m inside with streak -4, pays white plus_mult", function()
		set_hand(g, "white", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . W W . . . .",
			". . W . . W . . .",
			". . W . . W . . .",
			". . . W . W . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 3, 4, -4)
		local snap = player_score_snapshot(g, "white")
		local expected_delta = S.mult_control_streak_multiplier * 4
		test_helper.place_stone_for(g, "white", "mult_3_rounds_stone", {
			". . . . . . . . .",
			". . . W W . . . .",
			". . W m . W . . .",
			". . W . . W . . .",
			". . . W . W . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "white", snap, expected_delta, "white streak -4 in U-shape pocket")
	end)

	it("uncontrolled cell (streak 0) inside black enclosure, pays nothing", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
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
		test_helper.set_territory_control_rounds(g, 5, 5, 0)
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B M B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, 0, "streak 0 gives no payout")
	end)

	it("black M inside white rectangular enclosure (streak -2), pays nothing", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . W W W W . . .",
			". . W . . W . . .",
			". . W . . W . . .",
			". . . W W W . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 4, 4, -2)
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . W W W W . . .",
			". . W M . W . . .",
			". . W . . W . . .",
			". . . W W W . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, 0, "black on white territory pays nothing")
	end)

	it("white m inside black rectangular enclosure (streak +5), pays nothing", function()
		set_hand(g, "white", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B . . .",
			". . B . . B . . .",
			". . B . . B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 4, 4, 5)
		local snap = player_score_snapshot(g, "white")
		test_helper.place_stone_for(g, "white", "mult_3_rounds_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B . . .",
			". . B m . B . . .",
			". . B . . B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "white", snap, 0, "white on black territory pays nothing")
	end)

	it("board-edge white enclosure (fixture #5), m with streak -3", function()
		set_hand(g, "white", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . B . . . . .",
			"W W W . . . . . .",
			". B . W . . . . .",
			". B B W . . . . .",
			". . . W . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 9, 2, -3)
		local snap = player_score_snapshot(g, "white")
		local expected_delta = S.mult_control_streak_multiplier * 3
		test_helper.place_stone_for(g, "white", "mult_3_rounds_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . B . . . . .",
			"W W W . . . . . .",
			". B . W . . . . .",
			". B B W . . . . .",
			". m . W . . . . .",
		})
		assert_player_plus_mult_delta(g, "white", snap, expected_delta, "board-edge pocket streak -3")
	end)

	it("corner 3x3 enclosure, M with streak 2", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
		set_board(g, {
			"B B B . . . . . .",
			"B . B . . . . . .",
			"B B B . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 2, 2, 2)
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 2
		place_stone(g, {
			"B B B . . . . . .",
			"B M B . . . . . .",
			"B B B . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta, "corner pocket streak 2")
	end)

	it("two enclosures on board, M reads only its own cell streak", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B B B . W W W .",
			". B . B . W . W .",
			". B B B . W W W .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 3, 3, 2)
		test_helper.set_territory_control_rounds(g, 3, 7, -5)
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 2
		place_stone(g, {
			". . . . . . . . .",
			". B B B . W W W .",
			". B M B . W . W .",
			". B B B . W W W .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta,
			"reads own pocket streak +2, ignores opponent pocket streak -5")
	end)

	it("nested: inner black ring inside outer white, M in inner pocket pays from black streak", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . . . . . . .",
			". W W W W W W . .",
			". W . . . . W . .",
			". W . B B B W . .",
			". W . B . B W . .",
			". W . B B B W . .",
			". W . . . . W . .",
			". W W W W W W . .",
			". . . . . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 5, 5, 4)
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 4
		place_stone(g, {
			". . . . . . . . .",
			". W W W W W W . .",
			". W . . . . W . .",
			". W . B B B W . .",
			". W . B M B W . .",
			". W . B B B W . .",
			". W . . . . W . .",
			". W W W W W W . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta,
			"inner pocket beats outer enclosure, black streak 4")
	end)

	it("white stones inside black enclosure, M in opponent-controlled zone pays 0", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B B B B B B . .",
			". B . . . . B . .",
			". B . W W . B . .",
			". B . . . W B . .",
			". B . . W . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 5, 4, -2)
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". B B B B B B . .",
			". B . . . . B . .",
			". B . W W . B . .",
			". B . M . W B . .",
			". B . . W . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, 0,
			"white-dominated zone inside black enclosure, black M gets nothing")
	end)

	it("gap between nested walls: M in black zone between outer black and inner white", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B B B B B B . .",
			". B . . . . B . .",
			". B . W W . B . .",
			". B . . . W B . .",
			". B . . W . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 3, 3, 6)
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 6
		place_stone(g, {
			". . . . . . . . .",
			". B B B B B B . .",
			". B M . . . B . .",
			". B . W W . B . .",
			". B . . . W B . .",
			". B . . W . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta,
			"gap cell streak 6 in own enclosure")
	end)

	it("diagonal enclosure (fixture #14), M in black pocket with streak 3", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			"B B . . . . . . .",
			". . B . . . . . .",
			"W . B . . . . . .",
			". W W B . . . . .",
			". . B W . . . . .",
			"B B . W W . . . .",
			". . . . W . . . .",
		})
		test_helper.set_territory_control_rounds(g, 4, 2, 3)
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 3
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			"B B . . . . . . .",
			". M B . . . . . .",
			"W . B . . . . . .",
			". W W B . . . . .",
			". . B W . . . . .",
			"B B . W W . . . .",
			". . . . W . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta,
			"irregular diagonal pocket streak 3")
	end)

	it("streak 1 yields minimal payout equal to mult_control_streak_multiplier", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
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
		test_helper.set_territory_control_rounds(g, 5, 5, 1)
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 1
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B M B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta,
			"streak 1 boundary value")
	end)

	it("payout fires once on placement, no recurring after 3 rounds", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
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
		test_helper.set_territory_control_rounds(g, 5, 5, 3)
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B M B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap_after = player_score_snapshot(g, "black")
		advance_rounds(g, 3)
		assert_player_plus_mult_unchanged(g, "black", snap_after,
			"one-time trigger, no recurring payout after rounds")
	end)

	it("complex board (fixture #13), M in black enclosed pocket with streak 4", function()
		set_hand(g, "black", { "mult_3_rounds_stone" })
		set_board(g, {
			". . . W . . W . .",
			". B . W . . W . .",
			"B . W B B B W . .",
			". W B W . W B W B",
			". W B . W . B W .",
			". . W B B B . W .",
			". B . W . . . W .",
			"W W W . . . . . W",
			". . . . . . . . .",
		})
		test_helper.set_territory_control_rounds(g, 5, 4, 4)
		local snap = player_score_snapshot(g, "black")
		local expected_delta = S.mult_control_streak_multiplier * 4
		place_stone(g, {
			". . . W . . W . .",
			". B . W . . W . .",
			"B . W B B B W . .",
			". W B W . W B W B",
			". W B M W . B W .",
			". . W B B B . W .",
			". B . W . . . W .",
			"W W W . . . . . W",
			". . . . . . . . .",
		})
		assert_player_plus_mult_delta(g, "black", snap, expected_delta,
			"complex board, black pocket streak 4")
	end)
end)
