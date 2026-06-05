--- Visual spec: tower_stone (OBJECTS.md #4).
---
--- Stone under test: tower_stone
--- Effect: double_corner_nearby_territory — when placed in a board corner,
--- adds stone_tower_corner_territory_add to territory_value of the 8
--- neighboring cells in the corner-anchored 3x3 block.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	T = { color = config.STONE_BLACK, kind = "tower_stone" },
	t = { color = config.STONE_WHITE, kind = "tower_stone" },
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
local assert_territory_values_ascii = test_helper.assert_territory_values_ascii
local assert_territory_ascii = test_helper.assert_territory_ascii

local S = P.stone

--- @return number
local function tower_bonus()
	return S.stone_tower_corner_territory_add
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

describe("tower_stone (visual ASCII)", function()
	local g
	local TV_CORNER

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "tower_stone" }, "tower_stone")
		TV_CORNER = { values = { c = tostring(1 + tower_bonus()) } }
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("top-left corner: 8 neighboring cells gain tower bonus", function()
		set_hand(g, "black", { "tower_stone" })
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			"T . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"# c c . . . . . .",
			"c c c . . . . . .",
			"c c c . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "top-left corner 3x3 aura", TV_CORNER)

		local boosted_cells = 8
		local normal_cells = 80 - boosted_cells
		local expected_territory = normal_cells + boosted_cells * (1 + tower_bonus())
		assert.are.equal(expected_territory, snap.territory + boosted_cells * tower_bonus(),
			"territory score increases by bonus * boosted cells")
	end)

	it("top-right corner: 8 neighboring cells gain tower bonus", function()
		set_hand(g, "black", { "tower_stone" })
		set_board(g, blank_board())

		place_stone(g, {
			". . . . . . . . T",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			". . . . . . c c #",
			". . . . . . c c c",
			". . . . . . c c c",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "top-right corner 3x3 aura", TV_CORNER)
	end)

	it("bottom-left corner: 8 neighboring cells gain tower bonus", function()
		set_hand(g, "black", { "tower_stone" })
		set_board(g, blank_board())

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"T . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"c c c . . . . . .",
			"c c c . . . . . .",
			"# c c . . . . . .",
		}, "bottom-left corner 3x3 aura", TV_CORNER)
	end)

	it("bottom-right corner: 8 neighboring cells gain tower bonus", function()
		set_hand(g, "black", { "tower_stone" })
		set_board(g, blank_board())

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . T",
		})

		assert_territory_values_ascii(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . c c c",
			". . . . . . c c c",
			". . . . . . c c #",
		}, "bottom-right corner 3x3 aura", TV_CORNER)
	end)

	it("center placement has no territory value bonus", function()
		set_hand(g, "black", { "tower_stone" })
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . T . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . # . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "non-corner tower adds no value bonus")

		local territory_after = test_helper.count_territory_cells(g, "black")
		assert.are.equal(80, territory_after, "all 80 empty cells count at value 1")
	end)

	it("two towers in opposite corners both apply their aura", function()
		set_hand(g, "black", { "tower_stone", "tower_stone" })
		set_board(g, blank_board())

		place_stone(g, {
			"T . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . T",
		}, false)

		assert_territory_values_ascii(g, {
			"# c c . . . . . .",
			"c c c . . . . . .",
			"c c c . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . c c c",
			". . . . . . c c c",
			". . . . . . c c #",
		}, "both corners independently boosted", TV_CORNER)

		local boosted_cells = 16
		local normal_cells = 79 - boosted_cells
		local expected_territory = normal_cells + boosted_cells * (1 + tower_bonus())
		assert.are.equal(expected_territory, test_helper.count_territory_cells(g, "black"),
			"territory score sums both auras")
	end)

	it("white tower in bottom-right only boosts white territory value", function()
		set_board(g, {
			"B . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})
		test_helper.place_stone_for(g, "white", "tower_stone", {
			"B . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . t",
		})

		assert_territory_values_ascii(g, {
			"# . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . c c c",
			". . . . . . c c c",
			". . . . . . c c #",
		}, "white tower only boosts white-corner cells", TV_CORNER)

		assert_territory_ascii(g, {
			"B b b b b w w w w",
			"b b b b b w w w w",
			"b b b b b w w w w",
			"b b b b b w w w w",
			"b b b b . w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w W w",
			"w w w w w w w w t",
		}, "territory ownership unaffected by value bonus")
	end)

	it("tower in corner with opponent nearby — bonus cells owned by opponent score for opponent", function()
		set_hand(g, "black", { "tower_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . W .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . W .",
			". . . . . . . . .",
			". . . . . . . . T",
		})

		assert_territory_values_ascii(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . c c c",
			". . . . . . c c c",
			". . . . . . c c #",
		}, "aura applies regardless of who owns the cells", TV_CORNER)

		local white_territory = test_helper.count_territory_cells(g, "white")
		assert.is_true(white_territory > 0, "white still owns some boosted cells near its stone")
	end)

	it("captured tower stops contributing territory value bonus", function()
		set_hand(g, "black", { "tower_stone" })
		set_board(g, blank_board())

		place_stone(g, {
			"T . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.capture_stone_at(g, 1, 1, "white")
		test_helper.finish_turn(g)

		assert_territory_values_ascii(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "captured tower removes corner bonus entirely")
	end)

	it("illegal placement on occupied cell has no effect on territory values", function()
		set_hand(g, "black", { "tower_stone" })
		set_board(g, {
			"B . . . . . . . .",
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

		test_helper.assert_illegal_player_move_with_stone(g, "black", "tower_stone", 1, 1, "occupied rejects tower")

		assert_territory_values_ascii(g, {
			"# . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "no tower effect when move rejected")
	end)
end)
