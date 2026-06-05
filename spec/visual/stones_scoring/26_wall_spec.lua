--- Visual spec: wall (OBJECTS.md #26).
---
--- Stone under test: wall
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_BLACK, kind = "wall" },
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
local assert_pattern_stones_in_content = test_helper.assert_pattern_stones_in_content
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_board_stone_modifier_absent = test_helper.assert_board_stone_modifier_absent

describe("wall (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"wall"}, "wall")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("wall stone connected group points", function()
		it("basic stone beside walls gets no placement points and no wall bonus", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "stone_basic" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W . . . .",
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
				". . . W W B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_unchanged(g, "black", snap, "basic stone placement adds no points")
			assert_board_stone_modifier_absent(g, 3, 3, "existing wall at 3,3 has no points bonus")
			assert_board_stone_modifier_absent(g, 3, 4, "existing wall at 3,4 has no points bonus")
		end)

		it("third wall in a row adds no bonus below 5 connected stones", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W . . . .",
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
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_unchanged(g, "black", snap, "3 connected walls grant no wall bonus")
		end)

		it("fifth wall in a row adds +5 for 5 connected stones", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . W W W W . . .",
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
				". . W W W W W . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, P.wall_points(5), "5 connected walls grant wall block bonus")
		end)

		it("wall as 5th stone in mixed group adds +5", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B B B B .",
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
				". . . W B B B B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, P.wall_points(5), "wall joining 4 basics to 5 connected")
		end)

		it("tenth connected stone via wall placement adds +10", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B . B B .",
				". . . B B B B B .",
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
				". . . B B W B B .",
				". . . B B B B B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, P.wall_points(10), "10 connected stones grant wall bonus on placement")
		end)

		it("sixth connected wall adds +5 not +10", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . W W W W W . .",
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
				". . W W W W W W .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, P.wall_points(6), "6 connected walls still grant only one wall block")
		end)
	end)
end)
