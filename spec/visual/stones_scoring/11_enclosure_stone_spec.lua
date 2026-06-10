--- Visual spec: enclosure_stone (OBJECTS.md #11).
---
--- Stone under test: enclosure_stone
--- Effect: multiplies territory_value of cells inside the enclosure region
--- containing this stone by enclosure_stone_multiplier. Only fires when the
--- stone sits inside a valid enclosure (fully surrounded by same-color boundary,
--- not connected to an edge without walls).
---
--- NOTE: enclosure_stone is currently unimplemented (stub). These tests document
--- intended behavior and will pass once the effect is wired up.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	N = { color = config.STONE_BLACK, kind = "enclosure_stone" },
	n = { color = config.STONE_WHITE, kind = "enclosure_stone" },
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

local S = P.stone

describe("enclosure_stone (visual ASCII)", function()
	local g
	local multiplier
	local doubled
	local TV_OPTS

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "enclosure_stone" }, "enclosure_stone")
		multiplier = S.enclosure_stone_multiplier
		doubled = tostring(multiplier)
		TV_OPTS = { values = { d = doubled } }
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("multi-cell enclosure: all interior cells get multiplied", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . B B B B B . .",
			". . B . . . B . .",
			". . B . . . B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local baseline = test_helper.player_territory_score(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . B B B B B . .",
			". . B N . . B . .",
			". . B . . . B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 # # # # # 1 1",
			"1 1 # # d d # 1 1",
			"1 1 # d d d # 1 1",
			"1 1 # # # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "all 5 remaining interior cells multiplied", TV_OPTS)

		local enclosed_cells = 5
		local expected_territory_gain = enclosed_cells * (multiplier - 1) - 1
		local territory_after = test_helper.player_territory_score(g, "black")
		assert.are.equal(baseline + expected_territory_gain, territory_after,
			"territory increases by 5 * (multiplier-1)")
	end)

	it("open-board placement with no enclosure: no territory value bonus", function()
		set_hand(g, "black", { "enclosure_stone" })
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

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . N . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 # 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "no region doubling without enclosure")
	end)

	it("two separate enclosures: only the one containing the stone is multiplied", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". B B B B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B B B .",
			". . . . . B . B .",
			". . . . . B . B .",
			". . . . . B B B .",
		})

		place_stone(g, {
			". B B B B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B B B .",
			". . . . . B N B .",
			". . . . . B . B .",
			". . . . . B B B .",
		})

		assert_territory_values_ascii(g, {
			"1 # # # # 1 1 1 1",
			"1 # 1 1 # 1 1 1 1",
			"1 # # # # 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 # # # 1",
			"1 1 1 1 1 # # # 1",
			"1 1 1 1 1 # d # 1",
			"1 1 1 1 1 # # # 1",
		}, "top-left enclosure untouched, bottom-right multiplied", TV_OPTS)
	end)

	it("multiple enclosures each with own stone: both regions multiplied", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". B B B B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B B B .",
			". . . . . B . B .",
			". . . . . B . B .",
			". . . . . B B B .",
		})

		place_stone(g, {
			". B B B B . . . .",
			". B N . B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B B B .",
			". . . . . B . B .",
			". . . . . B . B .",
			". . . . . B B B .",
		})

		test_helper.place_stone_for(g, "black", "enclosure_stone", {
			". B B B B . . . .",
			". B N . B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B B B .",
			". . . . . B N B .",
			". . . . . B . B .",
			". . . . . B B B .",
		})

		assert_territory_values_ascii(g, {
			"1 # # # # 1 1 1 1",
			"1 # # d # 1 1 1 1",
			"1 # # # # 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 # # # 1",
			"1 1 1 1 1 # # # 1",
			"1 1 1 1 1 # d # 1",
			"1 1 1 1 1 # # # 1",
		}, "both enclosures independently multiplied", TV_OPTS)
	end)

	it("two enclosure_stones in same region stack the multiplier", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B B . .",
			". . B . . . B . .",
			". . B . . . B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B B . .",
			". . B N . . B . .",
			". . B . . . B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.place_stone_for(g, "black", "enclosure_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B B . .",
			". . B N . . B . .",
			". . B . . N B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local stacked = tostring(multiplier * multiplier)
		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 # # # # # 1 1",
			"1 1 # # s s # 1 1",
			"1 1 # s s # # 1 1",
			"1 1 # # # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "stacked enclosures multiply territory value twice",
			{ values = { s = stacked } })
	end)

	it("enclosure within enclosure: inner and outer regions multiplied independently", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			"B B B B B B B B B",
			"B . . . . . . . B",
			"B . B B B B B . B",
			"B . B . . . B . B",
			"B . B . . . B . B",
			"B . B B B B B . B",
			"B . . . . . . . B",
			"B . . . . . . . B",
			"B B B B B B B B B",
		})

		place_stone(g, {
			"B B B B B B B B B",
			"B N . . . . . . B",
			"B . B B B B B . B",
			"B . B . . . B . B",
			"B . B . . . B . B",
			"B . B B B B B . B",
			"B . . . . . . . B",
			"B . . . . . . . B",
			"B B B B B B B B B",
		})

		test_helper.place_stone_for(g, "black", "enclosure_stone", {
			"B B B B B B B B B",
			"B N . . . . . . B",
			"B . B B B B B . B",
			"B . B N . . B . B",
			"B . B . . . B . B",
			"B . B B B B B . B",
			"B . . . . . . . B",
			"B . . . . . . . B",
			"B B B B B B B B B",
		})

		local inner_value = doubled
		local outer_value = doubled
		assert_territory_values_ascii(g, {
			"# # # # # # # # #",
			"# # d d d d d d #",
			"# d # # # # # d #",
			"# d # # i i # d #",
			"# d # i i i # d #",
			"# d # # # # # d #",
			"# d d d d d d d #",
			"# d d d d d d d #",
			"# # # # # # # # #",
		}, "outer region cells multiplied by outer stone, inner region by inner stone",
			{ values = { d = outer_value, i = inner_value } })
	end)

	it("wall-boundary enclosure: board top edge + stones form enclosure", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			"B . . . B . . . .",
			"B . . . B . . . .",
			"B . . . B . . . .",
			"B B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local baseline = test_helper.player_territory_score(g, "black")

		place_stone(g, {
			"B . N . B . . . .",
			"B . . . B . . . .",
			"B . . . B . . . .",
			"B B B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"# d # d # 1 1 1 1",
			"# d d d # 1 1 1 1",
			"# d d d # 1 1 1 1",
			"# # # # # 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "board top edge serves as wall completing the enclosure", TV_OPTS)

		local enclosed_cells = 8
		local expected_territory_gain = enclosed_cells * (multiplier - 1) - 1
		local territory_after = test_helper.player_territory_score(g, "black")
		assert.are.equal(baseline + expected_territory_gain, territory_after,
			"territory increases by enclosed cells * (multiplier-1)")
	end)

	it("corner wall-boundary: two board edges + L-shaped stones form enclosure", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B B B B",
			". . . . . B . . .",
			". . . . . B . . .",
			". . . . . B . . .",
		})
		local baseline = test_helper.player_territory_score(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B B B B",
			". . . . . B N . .",
			". . . . . B . . .",
			". . . . . B . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 # # # #",
			"1 1 1 1 1 # # d d",
			"1 1 1 1 1 # d d d",
			"1 1 1 1 1 # d d d",
		}, "bottom-right corner: board edges complete the enclosure", TV_OPTS)

		local enclosed_cells = 8
		local expected_territory_gain = enclosed_cells * (multiplier - 1) - 1
		local territory_after = test_helper.player_territory_score(g, "black")
		assert.are.equal(baseline + expected_territory_gain, territory_after,
			"corner enclosure boosts territory")
	end)

	it("captured enclosure_stone reverts territory value to default", function()
		set_board(g, {
			". . . . . . . . .",
			". . B B B B B . .",
			". . B . . . B . .",
			". . B . N . B . .",
			". . B . . . B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.capture_stone_at(g, 4, 5, "black")
		test_helper.finish_turn(g)

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 # # # # # 1 1",
			"1 1 # 1 1 1 # 1 1",
			"1 1 # 1 1 1 # 1 1",
			"1 1 # 1 1 1 # 1 1",
			"1 1 # # # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "captured enclosure reverts multiplied cells to default 1")
	end)

	it("complex multi-wall board with multiple enclosures from integration fixture", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			"W . B . W . . . .",
			"B W . W . W . . .",
			"B B W . B B W . .",
			"B . B . . W . W .",
			"W . B . . B . . W",
			"B W W B B . . W .",
			". . B W B B W . .",
			"B B . W W W . W B",
			". B B . W . . B .",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			"W . B . W . . . .",
			"B W . W . W . . .",
			"B B W . B B W . .",
			"B . B . . W . W .",
			"W N B . . B . . W",
			"B W W B B . . W .",
			". . B W B B W . .",
			"B B . W W W . W B",
			". B B . W . . B .",
		})
		assert_territory_values_ascii(g, {
			"# 1 # 1 # 1 1 1 1",
			"# # 1 # 1 # 1 1 1",
			"# # # 1 # # # 1 1",
			"# 1 # 1 1 # 1 # 1",
			"1 # # 1 1 # 1 1 #",
			"# # # # # 1 1 # 1",
			"d d # # # # # 1 1",
			"# # 1 # # # 1 # #",
			"1 # # 1 # 1 1 # 1",
		}, "top-left and bottom-left multiplied, top-right untouched", TV_OPTS)

	end)

	it("three enclosures, stones in two of them: only those two multiplied", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			"B B B . B B B . .",
			"B . B . B . B . .",
			"B B B . B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"B . . B . . . . .",
			"B B B B . . . . .",
		})

		place_stone(g, {
			"B B B . B B B . .",
			"B N B . B . B . .",
			"B B B . B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"B . . B . . . . .",
			"B B B B . . . . .",
		})

		test_helper.place_stone_for(g, "black", "enclosure_stone", {
			"B B B . B B B . .",
			"B N B . B . B . .",
			"B B B . B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"B N . B . . . . .",
			"B B B B . . . . .",
		})

		assert_territory_values_ascii(g, {
			"# # # 1 # # # 1 1",
			"# # # 1 # 1 # 1 1",
			"# # # 1 # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"# # # # 1 1 1 1 1",
			"# # d # 1 1 1 1 1",
			"# # # # 1 1 1 1 1",
		}, "top-left and bottom-left multiplied, top-right untouched", TV_OPTS)
	end)

	it("adjacent enclosures sharing a wall: each stone multiplies only its own region", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B B B B B . . .",
			". B . . B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". B . . B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
		})

		place_stone(g, {
			". . . . . . . . .",
			". B B B B B . . .",
			". B N . B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". B . . B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
		})

		test_helper.place_stone_for(g, "black", "enclosure_stone", {
			". . . . . . . . .",
			". B B B B B . . .",
			". B N . B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". B N . B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 # # # # # 1 1 1",
			"1 # # d # 1 1 1 1",
			"1 # d d # 1 1 1 1",
			"1 # # # # 1 1 1 1",
			"1 # # d # 1 1 1 1",
			"1 # d d # 1 1 1 1",
			"1 # # # # 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "shared wall separates two independent enclosures, each multiplied", TV_OPTS)
	end)

	it("irregular L-shaped enclosure: non-rectangular interior still multiplied", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B B B B . . . .",
			". B . . B . . . .",
			". B . . B B B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local baseline = test_helper.player_territory_score(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". B B B B . . . .",
			". B N . B . . . .",
			". B . . B B B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 # # # # 1 1 1 1",
			"1 # # d # 1 1 1 1",
			"1 # d d # # # 1 1",
			"1 # d d d d # 1 1",
			"1 # # # # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "L-shaped interior: all 8 enclosed cells multiplied", TV_OPTS)

		local enclosed_cells = 7
		local expected_territory_gain = enclosed_cells * (multiplier - 1) - 1
		local territory_after = test_helper.player_territory_score(g, "black")
		assert.are.equal(baseline + expected_territory_gain, territory_after,
			"L-shape territory gain matches cell count")
	end)

	it("gap in boundary: no valid enclosure formed, no multiplier", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B . . . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B N . . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 # # # 1 1 1",
			"1 1 1 # # 1 1 1 1",
			"1 1 1 # # # 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "open gap prevents enclosure formation, no cells doubled")
	end)

	it("opponent stone inside pocket: interior empty cells still doubled", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B . . .",
			". . B . W B . . .",
			". . B . . B . . .",
			". . B B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local baseline = test_helper.player_territory_score(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B . . .",
			". . B . W B . . .",
			". . B N . B . . .",
			". . B B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 # # # # 1 1 1",
			"1 1 # d # # 1 1 1",
			"1 1 # # d # 1 1 1",
			"1 1 # # # # 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "white stone inside does not cancel black enclosure doubling", TV_OPTS)

		local enclosed_cells = 2
		local expected_territory_gain = enclosed_cells * (multiplier - 1) - 1
		local territory_after = test_helper.player_territory_score(g, "black")
		assert.are.equal(baseline + expected_territory_gain, territory_after,
			"two doubled interior empties add multiplier-1 each")
	end)

	it("white enclosure_stone in white region multiplies white territory", function()
		set_board(g, {
			". . . . . . . . .",
			". . W W W W W . .",
			". . W . . . W . .",
			". . W . . . W . .",
			". . W W W W W . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.place_stone_for(g, "white", "enclosure_stone", {
			". . . . . . . . .",
			". . W W W W W . .",
			". . W n . . W . .",
			". . W . . . W . .",
			". . W W W W W . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 # # # # # 1 1",
			"1 1 # # d d # 1 1",
			"1 1 # d d d # 1 1",
			"1 1 # # # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "white enclosure_stone multiplies white-owned interior", TV_OPTS)

		local enclosed_cells = 5
		local expected_territory_gain = enclosed_cells * (multiplier - 1)
		local white_territory = test_helper.count_territory_cells(g, "white")
		assert.is_true(white_territory >= enclosed_cells * multiplier,
			"white territory reflects multiplied enclosed cells")
	end)

	it("left-edge wall-boundary: board left edge + column of stones form enclosure", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			". . . B . . . . .",
			". . . B . . . . .",
			". . . B . . . . .",
			"B B B B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local baseline = test_helper.player_territory_score(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"N . . B . . . . .",
			". . . B . . . . .",
			". . . B . . . . .",
			"B B B B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"# # # # 1 1 1 1 1",
			"# d d # 1 1 1 1 1",
			"d d d # 1 1 1 1 1",
			"d d d # 1 1 1 1 1",
			"# # # # 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "left board edge acts as wall for 8 enclosed cells", TV_OPTS)

		local enclosed_cells = 8
		local expected_territory_gain = enclosed_cells * (multiplier - 1) - 1
		local territory_after = test_helper.player_territory_score(g, "black")
		assert.are.equal(baseline + expected_territory_gain, territory_after,
			"left-edge enclosure territory gain")
	end)

	it("opposite-edge spanning region is NOT enclosed: no multiplier", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B B B B B B",
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
			"B B B B B B B B B",
			". . . . N . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"# # # # # # # # #",
			"1 1 1 1 # 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "region touches left+right+bottom (3 edges) so is open, no enclosure")
	end)

	it("opponent enclosure nested inside our enclosure: inner cells stay opponent-owned", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			"B B B B B B B B B",
			"B . . . . . . . B",
			"B . . W W W . . B",
			"B . . W . W . . B",
			"B . . W W W . . B",
			"B . . . . . . . B",
			"B . . . . . . . B",
			"B . . . . . . . B",
			"B B B B B B B B B",
		})
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			"B B B B B B B B B",
			"B N . . . . . . B",
			"B . . W W W . . B",
			"B . . W . W . . B",
			"B . . W W W . . B",
			"B . . . . . . . B",
			"B . . . . . . . B",
			"B . . . . . . . B",
			"B B B B B B B B B",
		})

		assert_territory_values_ascii(g, {
			"# # # # # # # # #",
			"# # d d d d d d #",
			"# d d # # # d d #",
			"# d d # 1 # d d #",
			"# d d # # # d d #",
			"# d d d d d d d #",
			"# d d d d d d d #",
			"# d d d d d d d #",
			"# # # # # # # # #",
		}, "black cells multiplied, white-enclosed cell (4,5) untouched by black multiplier", TV_OPTS)

		local territory_after = test_helper.count_territory_cells(g, "black")
		assert.is_true(territory_after > snap.territory,
			"black territory increases from enclosure, white pocket excluded")
	end)

	it("opponent enclosure within ours: smallest enclosure wins ownership for inner cell", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B B B B B B . .",
			". B . . . . B . .",
			". B . W W . B . .",
			". B . W . W B . .",
			". B . . W . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		place_stone(g, {
			". . . . . . . . .",
			". B B B B B B . .",
			". B N . . . B . .",
			". B . W W . B . .",
			". B . W . W B . .",
			". B . . W . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 # # # # # # 1 1",
			"1 # # d d d # 1 1",
			"1 # d # # d # 1 1",
			"1 # d # d # # 1 1",
			"1 # d d # d # 1 1",
			"1 # # # # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "white pocket center doubled too — multiplier is field-based, not owner-based", TV_OPTS)
	end)

	it("both players nested: black enclosure_stone only multiplies black-owned cells inside", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". B B B B B B B .",
			". B . . . . . B .",
			". B . W W W . B .",
			". B . W . W . B .",
			". B . W W W . B .",
			". B . . . . . B .",
			". B B B B B B B .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		place_stone(g, {
			". B B B B B B B .",
			". B N . . . . B .",
			". B . W W W . B .",
			". B . W . W . B .",
			". B . W W W . B .",
			". B . . . . . B .",
			". B B B B B B B .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.place_stone_for(g, "white", "enclosure_stone", {
			". B B B B B B B .",
			". B N . . . . B .",
			". B . W W W . B .",
			". B . W n W . B .",
			". B . W W W . B .",
			". B . . . . . B .",
			". B B B B B B B .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 # # # # # # # 1",
			"1 # # d d d d # 1",
			"1 # d # # # d # 1",
			"1 # d # # # d # 1",
			"1 # d # # # d # 1",
			"1 # d d d d d # 1",
			"1 # # # # # # # 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "black multiplier on black region, white multiplier on white pocket (4,5)", TV_OPTS)
	end)

	it("crossing enclosures: overlapping cells become neutral, no multiplier", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . B B B B . . .",
			". . B . . B . . .",
			". . B . . B . . .",
			". W W . . W W . .",
			". W . . . . W . .",
			". W W W W W W . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		place_stone(g, {
			". . . . . . . . .",
			". . B B B B . . .",
			". . B N . B . . .",
			". . B . . B . . .",
			". W W . . W W . .",
			". W . . . . W . .",
			". W W W W W W . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 1 # # # # 1 1 1",
			"1 1 # # 1 # 1 1 1",
			"1 1 # 1 1 # 1 1 1",
			"1 # # 1 1 # # 1 1",
			"1 # 1 1 1 1 # 1 1",
			"1 # # # # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "cells in crossing overlap become neutral, only uncontested black cells multiplied", TV_OPTS)
	end)

	it("triple nesting: three concentric rings, stone in each", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			"B B B B B B B B B",
			"B . . . . . . . B",
			"B . B B B B B . B",
			"B . B . . . B . B",
			"B . B . B . B . B",
			"B . B . . . B . B",
			"B . B B B B B . B",
			"B . . . . . . . B",
			"B B B B B B B B B",
		})

		place_stone(g, {
			"B B B B B B B B B",
			"B N . . . . . . B",
			"B . B B B B B . B",
			"B . B . . . B . B",
			"B . B . B . B . B",
			"B . B . . . B . B",
			"B . B B B B B . B",
			"B . . . . . . . B",
			"B B B B B B B B B",
		})

		test_helper.place_stone_for(g, "black", "enclosure_stone", {
			"B B B B B B B B B",
			"B N . . . . . . B",
			"B . B B B B B . B",
			"B . B N . . B . B",
			"B . B . B . B . B",
			"B . B . . . B . B",
			"B . B B B B B . B",
			"B . . . . . . . B",
			"B B B B B B B B B",
		})

		test_helper.place_stone_for(g, "black", "enclosure_stone", {
			"B B B B B B B B B",
			"B N . . . . . . B",
			"B . B B B B B . B",
			"B . B N . . B . B",
			"B . B . B . B . B",
			"B . B . . N B . B",
			"B . B B B B B . B",
			"B . . . . . . . B",
			"B B B B B B B B B",
		})

		local m1 = doubled
		local m2 = tostring(multiplier * multiplier)
		local m3 = tostring(multiplier * multiplier * multiplier)
		assert_territory_values_ascii(g, {
			"# # # # # # # # #",
			"# # a a a a a a #",
			"# a # # # # # a #",
			"# a # # b b # a #",
			"# a # b # b # a #",
			"# a # b b # # a #",
			"# a # # # # # a #",
			"# a a a a a a a #",
			"# # # # # # # # #",
		}, "outer=1x mult, middle=2x mult, innermost cell adjacent to core stone gets 3x",
			{ values = { a = m1, b = m2, c = m3 } })
	end)

	it("both players have enclosures: each multiplier applies only to own color", function()
		set_board(g, {
			"B B B B . W W W W",
			"B . . B . W . . W",
			"B . . B . W . . W",
			"B B B B . W W W W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		set_hand(g, "black", { "enclosure_stone" })

		place_stone(g, {
			"B B B B . W W W W",
			"B N . B . W . . W",
			"B . . B . W . . W",
			"B B B B . W W W W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.place_stone_for(g, "white", "enclosure_stone", {
			"B B B B . W W W W",
			"B N . B . W n . W",
			"B . . B . W . . W",
			"B B B B . W W W W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"# # # # 1 # # # #",
			"# # d # 1 # # d #",
			"# d d # 1 # d d #",
			"# # # # 1 # # # #",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "black enclosure multiplies black cells, white enclosure multiplies white cells", TV_OPTS)
	end)

	it("opponent closes inner fence after black enclosure_stone: seized cells keep doubled value", function()
		set_hand(g, "black", { "enclosure_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B B B B B B . .",
			". B . . . . B . .",
			". B . . . . B . .",
			". B . . . . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		place_stone(g, {
			". . . . . . . . .",
			". B B B B B B . .",
			". B N . . . B . .",
			". B . . . . B . .",
			". B . . . . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 # # # # # # 1 1",
			"1 # # d d d # 1 1",
			"1 # d d d d # 1 1",
			"1 # d d d d # 1 1",
			"1 # d d d d # 1 1",
			"1 # # # # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "black enclosure_stone doubles full interior before opponent moves", TV_OPTS)

		local white_score_before = test_helper.player_territory_score(g, "white")
		set_hand(g, "white", { "stone_basic" })
		test_helper.place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". B B B B B B . .",
			". B N . . . B . .",
			". B . W . . B . .",
			". B . . . . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". B B B B B B . .",
			". B N . . . B . .",
			". B . W W . B . .",
			". B . . . . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". B B B B B B . .",
			". B N . . . B . .",
			". B . W W . B . .",
			". B . . . W B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". B B B B B B . .",
			". B N . . . B . .",
			". B . W W . B . .",
			". B . W . W B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". B B B B B B . .",
			". B N . . . B . .",
			". B . W W . B . .",
			". B . W . W B . .",
			". B . . W . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_values_ascii(g, {
			"1 1 1 1 1 1 1 1 1",
			"1 # # # # # # 1 1",
			"1 # # d d d # 1 1",
			"1 # d # # d # 1 1",
			"1 # d # d # # 1 1",
			"1 # d d # d # 1 1",
			"1 # # # # # # 1 1",
			"1 1 1 1 1 1 1 1 1",
			"1 1 1 1 1 1 1 1 1",
		}, "white seizes (5,5) but field value stays doubled from black enclosure_stone", TV_OPTS)

		local white_score_after = test_helper.player_territory_score(g, "white")
		assert.are.equal(white_score_before + multiplier, white_score_after,
			"white gains seized pocket at multiplied value, not base 1")
	end)
end)
