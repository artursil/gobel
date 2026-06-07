--- Visual spec: global capture bonus (docs/capture/scoring.md).
---
--- Cross-stone rule: capture_bonus_points_per_stone × enemy stones removed on placement.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	P = { color = config.STONE_BLACK, kind = "stone_power" },
	b = { color = config.STONE_WHITE, kind = "stone_power" },
	L = { color = config.STONE_BLACK, kind = "wall" },
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
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_board_cell_empty = test_helper.assert_board_cell_empty

--- @param capture_count integer
--- @return number
local function capture_bonus_for(capture_count)
	return P.capture_bonus_points(capture_count)
end

describe("global capture bonus (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("stone_basic single capture awards capture_bonus_points_per_stone", function()
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

		assert_board_cell_empty(g, 5, 5, "white stone captured")
		assert_player_points_delta(g, "black", snap, capture_bonus_for(1), "single capture bonus")
	end)

	it("two-stone group capture awards bonus per stone removed", function()
		set_hand(g, "black", { "stone_basic" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B B . .",
			". . . B W W B . .",
			". . . B . B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B B . .",
			". . . B W W B . .",
			". . . B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_board_cell_empty(g, 5, 5, "left chain stone captured")
		assert_board_cell_empty(g, 5, 6, "right chain stone captured")
		assert_player_points_delta(g, "black", snap, capture_bonus_for(2), "two-stone capture bonus")
	end)

	it("L-shaped three-stone capture awards 3x bonus", function()
		set_hand(g, "black", { "stone_basic" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W W B . .",
			". . . B W B B . .",
			". . . B . B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W W B . .",
			". . . B W B B . .",
			". . . B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, capture_bonus_for(3), "three-stone capture bonus")
	end)

	it("placement without capture awards no bonus", function()
		set_hand(g, "black", { "stone_basic" })
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
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_unchanged(g, "black", snap, "no capture means no bonus")
	end)

	it("white capture awards bonus to white player", function()
		set_hand(g, "white", { "stone_basic" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W B W . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "white")

		test_helper.place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . W . . . .",
			". . . W B W . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_board_cell_empty(g, 5, 5, "black stone captured by white")
		assert_player_points_delta(g, "white", snap, capture_bonus_for(1), "white receives capture bonus")
	end)

	it("stone_power awards placement points plus capture bonus", function()
		set_hand(g, "black", { "stone_power" })
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
			". . . . P . . . .",
			". . . B W B . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local expected_delta = P.stone_points("stone_power") + capture_bonus_for(1)
		assert_player_points_delta(g, "black", snap, expected_delta, "placement and capture bonuses stack")
	end)

	it("wall capture awards only capture bonus when group size below block threshold", function()
		set_hand(g, "black", { "wall" })
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
			". . . . L . . . .",
			". . . B W B . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, capture_bonus_for(1), "solo wall capture pays capture bonus only")
	end)

	it("pocket capture awards single-stone bonus", function()
		set_hand(g, "black", { "stone_basic" })
		set_board(g, {
			". . . . . . . . .",
			". . . . B . . . .",
			". . . B W B . . .",
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
			". . . . B . . . .",
			". . . B W B . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_board_cell_empty(g, 3, 5, "pocket white captured")
		assert_player_points_delta(g, "black", snap, capture_bonus_for(1), "pocket capture bonus")
	end)

	it("edge-adjacent capture awards single-stone bonus", function()
		set_hand(g, "black", { "stone_basic" })
		set_board(g, {
			". . . B W B . . .",
			". . . B . B . . .",
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
			". . . B W B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_board_cell_empty(g, 1, 5, "edge white captured")
		assert_player_points_delta(g, "black", snap, capture_bonus_for(1), "edge-adjacent capture bonus")
	end)

	it("capture attempt with remaining liberty awards no bonus", function()
		set_hand(g, "black", { "stone_basic" })
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
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.assert_board_stone_present(g, 5, 5, "target keeps a liberty")
		assert_player_points_unchanged(g, "black", snap, "no capture means no bonus")
	end)
end)
