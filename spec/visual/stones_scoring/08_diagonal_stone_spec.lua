--- Visual spec: diagonal_stone (OBJECTS.md #8).
---
--- Stone under test: diagonal_stone
--- Effect: wall-style placement bonus based on the diagonally-connected group
--- size. Connectivity is diagonal (NE, NW, SE, SW). Pays
--- floor(group_size / block_size) * points_per_block on placement.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	D = { color = config.STONE_BLACK, kind = "diagonal_stone" },
	d = { color = config.STONE_WHITE, kind = "diagonal_stone" },
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

local S = P.stone

--- @return integer
local function block_size()
	return S.diagonal_stone_block_size
end

--- @return integer
local function points_per_block()
	return S.diagonal_stone_points_per_block
end

--- @param group_size integer
--- @return integer
local function diagonal_bonus(group_size)
	return math.floor(group_size / block_size()) * points_per_block()
end

describe("diagonal_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "diagonal_stone" }, "diagonal_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("single diagonal_stone with no neighbors pays zero", function()
		set_hand(g, "black", { "diagonal_stone" })
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
			". . . . D . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, diagonal_bonus(1), "lone stone group of 1")
	end)

	it("diagonal line of 4 below block size pays zero", function()
		set_hand(g, "black", { "diagonal_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". . . . . . . B .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . D . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". . . . . . . B .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, diagonal_bonus(4), "4-stone diagonal below block threshold")
	end)

	it("diagonal line of exactly block_size pays one block of points", function()
		set_hand(g, "black", { "diagonal_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B . . . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B . . . . .",
			". . . . B . . . .",
			". . . . . D . . .",
			". . . . . . B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, diagonal_bonus(block_size()), "exact block_size diagonal pays one block")
	end)

	it("zigzag diagonal of 2*block_size pays double block points", function()
		set_hand(g, "black", { "diagonal_stone" })
		set_board(g, {
			"B . . . . . . . .",
			". B . . . . . . .",
			". . B . . . . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". . . . . . . B .",
			". . . . . . . . B",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			"B . . . . . . . .",
			". B . . . . . . .",
			". . B . . . . . .",
			". . . B . . . . .",
			". . . . D . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". . . . . . . B .",
			". . . . . . . . B",
		})

		assert_player_points_delta(g, "black", snap, diagonal_bonus(block_size() * 2), "full diagonal spanning board pays two blocks")
	end)

	it("bridge placement merges two diagonal groups into one", function()
		set_hand(g, "black", { "diagonal_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B . . . . . . .",
			". . B . . . . . .",
			". . . . . . . . .",
			". . . . B . . . .",
			". . . . . B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". B . . . . . . .",
			". . B . . . . . .",
			". . . D . . . . .",
			". . . . B . . . .",
			". . . . . B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, diagonal_bonus(5), "bridge merges two groups into one block")
	end)

	it("orthogonally adjacent stones do not count as diagonally connected", function()
		set_hand(g, "black", { "diagonal_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B B . .",
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
			". . D B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, diagonal_bonus(1), "horizontal row is not diagonally connected to placed stone")
	end)

	it("mixed diagonal cluster on contested board scores full group", function()
		set_hand(g, "black", { "diagonal_stone" })
		set_board(g, {
			"W . . . . . . . .",
			". B . . . W . . .",
			". . B . . . . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . W . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			"W . . . . . . . .",
			". B . . . W . . .",
			". . B . . . . . .",
			". . . B . . . . .",
			". . . . D . . . .",
			". . . . . . . . .",
			". . . . . . W . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})

		assert_player_points_delta(g, "black", snap, diagonal_bonus(5), "diagonal chain scores among opponent stones")
	end)

	it("white diagonal_stone pays white only", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			". . . . . . . W .",
			". . . . . . . . .",
		})
		local snap_white = player_score_snapshot(g, "white")
		local snap_black = player_score_snapshot(g, "black")

		test_helper.place_stone_for(g, "white", "diagonal_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . d . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			". . . . . . . W .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "white", snap_white, diagonal_bonus(4), "white receives diagonal bonus")
		assert_player_points_unchanged(g, "black", snap_black, "black points unchanged by white placement")
	end)

	it("illegal placement on occupied cell gives no bonus", function()
		set_hand(g, "black", { "diagonal_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B . . . . . . .",
			". . B . . . . . .",
			". . . B . . . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")

		test_helper.assert_illegal_player_move_with_stone(g, "black", "diagonal_stone", 4, 4, "occupied rejects diagonal_stone")

		assert_player_points_unchanged(g, "black", snap, "no payout on illegal diagonal placement")
	end)

	it("two placements on same turn each score their own diagonal group", function()
		set_hand(g, "black", { "diagonal_stone", "diagonal_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B . . . . . . .",
			". . B . . . . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". . . . . . . B .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". B . . . . . . .",
			". . B . . . . . .",
			". . . B . . . . .",
			". . . . D . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". . . . . . . B .",
			". . . . . . . . .",
		}, false)

		local snap_after_first = player_score_snapshot(g, "black")

		place_stone(g, {
			"D . . . . . . . .",
			". B . . . . . . .",
			". . B . . . . . .",
			". . . B . . . . .",
			". . . . D . . . .",
			". . . . . B . . .",
			". . . . . . B . .",
			". . . . . . . B .",
			". . . . . . . . .",
		}, false)

		assert_player_points_delta(g, "black", snap, diagonal_bonus(8), "first placement connects full diagonal chain")
		assert_player_points_delta(g, "black", snap_after_first, diagonal_bonus(9), "second placement extends chain by one")
	end)
end)
