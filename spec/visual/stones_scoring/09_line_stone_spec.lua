--- Visual spec: line_stone (OBJECTS.md #9).
---
--- Stone under test: line_stone
--- Effect: wall-style placement bonus — on placement, adds points per full block of
--- orthogonally connected stones (including the placed line_stone).
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	L = { color = config.STONE_BLACK, kind = "line_stone" },
	l = { color = config.STONE_WHITE, kind = "line_stone" },
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
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_illegal_player_move_with_stone = test_helper.assert_illegal_player_move_with_stone

local S = P.stone

--- @param group_size integer
--- @return integer
local function line_placement_bonus(group_size)
	return math.floor(group_size / S.line_stone_block_size) * S.line_stone_points_per_block
end

describe("line_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"line_stone"}, "line_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("line_stone wall-style placement", function()
		it("line_stone scenario 1: group below block size pays zero bonus", function()
			set_hand(g, "black", { "line_stone" })
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

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . L B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, line_placement_bonus(2), "sub-threshold line group")
		end)

		it("line_stone scenario 2: one block group pays configured block points", function()
			set_hand(g, "black", { "line_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			local block = S.line_stone_block_size

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . . L . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, 0, "one block line payout")
		end)

		it("line_stone scenario 3: two blocks pay double", function()
			set_hand(g, "black", { "line_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . B B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			local block = S.line_stone_block_size

			place_stone(g, {
				". . . . . . . . .",
				". . B B B B L . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, 5, "two-block line group")
		end)

		it("line_stone scenario 4: between one and two blocks pays one block only", function()
			set_hand(g, "black", { "line_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . B B B B . . .",
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
				". . B B B B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, 0, "nine-size group still one block short of two")
		end)

		it("line_stone scenario 5: connecting groups uses merged size", function()
			set_hand(g, "black", { "line_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . B B . B B . .",
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
				". . B B L B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, line_placement_bonus(5), "bridge creates five-stone group")
		end)

		it("line_stone scenario 6: basic stone does not trigger line bonus", function()
			set_hand(g, "black", { "stone_basic" })
			set_board(g, {
				". . . . . . . . .",
				". . B B B B . . .",
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
				". . B B B B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_unchanged(g, "black", snap, "stone_basic has no line wall bonus")
		end)

		it("line_stone scenario 7: edge row group counts correctly", function()
			set_hand(g, "black", { "line_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". B B B . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". B B B L . . . .",
			})

			assert_player_points_delta(g, "black", snap, line_placement_bonus(4), "bottom-edge four stone group")
		end)

		it("line_stone scenario 8: corner group counts correctly", function()
			set_hand(g, "black", { "line_stone" })
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
				"L B . . . . . . .",
				"B . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "black", snap, line_placement_bonus(3), "corner three-stone group")
		end)

		it("line_stone scenario 9: white line_stone pays white only", function()
			set_board(g, {
				". . . . . . . . .",
				". . W W W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "white")

			test_helper.place_stone_for(g, "white", "line_stone", {
				". . . . . . . . .",
				". . W W W l . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "white", snap, line_placement_bonus(4), "white receives line bonus")
		end)

		it("line_stone scenario 10: occupied cell rejects line_stone with no payout", function()
			set_hand(g, "black", { "line_stone" })
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

			assert_illegal_player_move_with_stone(g, "black", "line_stone", 5, 5, "occupied rejects line_stone")
			assert_player_points_unchanged(g, "black", snap, "no payout on illegal line placement")
		end)
	end)
end)
