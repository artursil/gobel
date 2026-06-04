--- Visual spec: inert baseline stone (1 stone).
---
--- Stones under test:
--- - stone_basic (entry basic_stone): no placement points, mult, or delayed effects (STONE_BASIC_PLACEMENT_POINTS = 0)
---
--- Multi-step time (option C): finish_turn(g), pass_turn(g)
---
--- Player-visible: points, plus_mult, x_mult unchanged by stone_basic placement
--- Source of truth: mds/STONES_IMPLEMENTATION_ENTRY.md §1
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
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
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_player_plus_mult_unchanged = test_helper.assert_player_plus_mult_unchanged
local assert_player_x_mult_unchanged = test_helper.assert_player_x_mult_unchanged

local S = P.stone

--- @return number
local function basic_placement_points()
	return S.stone_basic_placement_points
end

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

local STONE_IDS = { "stone_basic" }

describe("stone_basic inert placement (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content(STONE_IDS, "stone_basic")
		assert.are.equal(0, basic_placement_points(), "parameter STONE_BASIC_PLACEMENT_POINTS is zero")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("stone_basic scenario 1: center placement changes no score components", function()
		set_hand(g, "black", { "stone_basic" })
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
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

		assert_player_points_unchanged(g, "black", snap, "stone_basic adds no points")
		assert_player_plus_mult_unchanged(g, "black", snap, "stone_basic adds no plus_mult")
		assert_player_x_mult_unchanged(g, "black", snap, "stone_basic adds no x_mult")
	end)

	it("stone_basic scenario 2: end_of_turn adds no stone_basic payout", function()
		set_hand(g, "black", { "stone_basic" })
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
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

		local snap_after_place = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		assert_player_points_unchanged(g, "black", snap_after_place, "no end_of_turn points from stone_basic")
		assert_player_points_unchanged(g, "black", snap, "placement still contributed nothing")
	end)

	it("stone_basic scenario 3: no delayed effect after opponent pass", function()
		set_hand(g, "black", { "stone_basic" })
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
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

		local snap_after_place = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		test_helper.pass_turn(g)
		test_helper.pass_turn(g)

		assert_player_points_unchanged(g, "black", snap_after_place, "after full round cycle no stone_basic payout")
		assert_player_plus_mult_unchanged(g, "black", snap, "mult still unchanged across turns")
	end)

	it("stone_basic scenario 4: core capture allowed with zero stone-specific bonus", function()
		set_hand(g, "black", { "stone_basic" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B W B . . .",
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
			". . . B W B . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.assert_board_cell_empty(g, 5, 5, "core capture removes white stone")
		assert_player_points_unchanged(g, "black", snap, "stone_basic grants no capture bonus points")
		assert_player_plus_mult_unchanged(g, "black", snap, "stone_basic grants no capture bonus mult")
	end)

	it("stone_basic scenario 5: illegal placement rejects move with unchanged score", function()
		set_hand(g, "black", { "stone_basic" })
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

		test_helper.assert_illegal_player_move_with_stone(g, "black", "stone_basic", 5, 5, "occupied cell rejects stone_basic")

		assert_player_points_unchanged(g, "black", snap, "illegal placement does not change points")
		assert_player_x_mult_unchanged(g, "black", snap, "illegal placement does not change x_mult")
	end)
end)
