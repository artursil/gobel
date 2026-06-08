--- Visual spec: influence_stone (OBJECTS.md #3).
---
--- Stone under test: influence_stone
--- Effect: distance_bonus — reduces the stone's effective Manhattan distance
--- for territory assignment, letting it reach further and claim cells that
--- would otherwise be neutral or opponent-owned.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	I = { color = config.STONE_BLACK, kind = "influence_stone" },
	i = { color = config.STONE_WHITE, kind = "influence_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_stone_instance = test_helper.set_stone_instance
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local ensure_actor_turn = test_helper.ensure_actor_turn
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_territory_ascii = test_helper.assert_territory_ascii

local S = P.stone

describe("influence_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "influence_stone" }, "influence_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("basic stone on contested row leaves midline column neutral", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
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
			"B . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"b b b b . w w w w",
			"b b b b . w w w w",
			"b b b b . w w w w",
			"b b b b . w w w w",
			"B b b b . w w w W",
			"b b b b . w w w w",
			"b b b b . w w w w",
			"b b b b . w w w w",
			"b b b b . w w w w",
		}, "baseline: equidistant midline column stays neutral without distance bonus")
	end)

	it("tier1 on contested row claims midline column black", function()
		set_stone_instance(g, "black", 1, "influence_stone", 1)
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
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
			"I . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"b b b b b w w w w",
			"b b b b b w w w w",
			"b b b b b w w w w",
			"b b b b b w w w w",
			"B b b b b w w w W",
			"b b b b b w w w w",
			"b b b b b w w w w",
			"b b b b b w w w w",
			"b b b b b w w w w",
		}, "tier1 bonus shifts boundary one column past basic stone reach")
	end)

	it("tier2 contested row leaves next column neutral at distance tie", function()
		set_stone_instance(g, "black", 1, "influence_stone", 2)
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
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
			"I . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"B b b b b . w w W",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
		}, "tier2 reaches midline but column 6 stays neutral on equidistant tie")
	end)

	it("tier3 on contested row claims one column further than tier2", function()
		set_stone_instance(g, "black", 1, "influence_stone", 3)
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
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
			"I . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"b b b b b b w w w",
			"b b b b b b w w w",
			"b b b b b b w w w",
			"b b b b b b w w w",
			"B b b b b b w w W",
			"b b b b b b w w w",
			"b b b b b b w w w",
			"b b b b b b w w w",
			"b b b b b b w w w",
		}, "tier3 bonus breaks tier2 tie and claims column 6 for black")
	end)

	it("tier ordering: T1 < T2 < T3 in parameters", function()
		assert.is_true(S.influence_t1 < S.influence_t2 and S.influence_t2 < S.influence_t3, "influence tier bonuses preserve ordering")
	end)

	it("equidistant midline cells stay neutral even after influence placement", function()
		set_stone_instance(g, "black", 1, "influence_stone", 1)
		set_board(g, {
			". . . . . . . . .",
			". B . . . . . W .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". B . . . . . W .",
			". . . . . . . . .",
		})
		place_stone(g, {
			". . . . . . . . .",
			". B . . . . . W .",
			". . . . . . . . .",
			". . . . . . . . .",
			". I . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". B . . . . . W .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"b b b b . w w w w",
			"b B b b . w w W w",
			"b b b b b w w w w",
			"b b b b b . w w w",
			"b B b b b b w w w",
			"b b b b b . w w w",
			"b b b b b w w w w",
			"b B b b . w w W w",
			"b b b b . w w w w",
		}, "influence shifts nearby cells but does not override equidistant tie at column 5")
	end)

	it("tier2 influence reclaims interior cells on contested case-04 board", function()
		set_stone_instance(g, "black", 1, "influence_stone", 2)
		set_board(g, {
			"B B . . W . . . .",
			"B . . W . . . . .",
			". W W . . . . . .",
			"W W . . . B . . .",
			". . . . W W . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		place_stone(g, {
			"B B . . W . . . .",
			"B . . W . . . . .",
			". W W . . . . . .",
			"W W . . . B . . .",
			". . . I W W . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"B B w w W w w w w",
			"B w w W w w w w w",
			"w W W b b b b b b",
			"W W b b b B b b b",
			". b b B W W . . .",
			". b b B b . . . .",
			". b b b b . . . .",
			". b b b b . . . .",
			". b b b b . . . .",
		}, "tier2 influence pushes black reach into former white/neutral interior")
	end)

	it("two tier1 influence stones stack reach via sequential placements", function()
		set_stone_instance(g, "black", 1, "influence_stone", 1)
		set_stone_instance(g, "black", 2, "influence_stone", 1)
		set_hand(g, "black", { "influence_stone", "influence_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"I . . . . . . . .",
			". . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		ensure_actor_turn(g, "black")
		set_hand(g, "black", { "influence_stone", "influence_stone" })
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B . . . . . . . .",
			". . . . . . . . W",
			"I . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"B b b b b . w w w",
			"b b b b b w w w W",
			"B b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
		}, "two tier1 stones each extend independently with overlapping black reach")
	end)

	it("adjacent opponent stone does not prevent influence reach beyond", function()
		set_stone_instance(g, "black", 1, "influence_stone", 1)
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W . . . . .",
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
			". . . W I . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			". . . . b b b b b",
			". . . . b b b b b",
			". . . . b b b b b",
			". . . . b b b b b",
			". . . W B b b b b",
			". . . . b b b b b",
			". . . . b b b b b",
			". . . . b b b b b",
			". . . . b b b b b",
		}, "black influence still claims exterior cells beside adjacent white stone")
	end)

	it("captured influence stone reverts territory to opponent control", function()
		set_stone_instance(g, "black", 1, "influence_stone", 1)
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
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
			"I . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.capture_stone_at(g, 5, 1, "black")
		assert_territory_ascii(g, {
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w W",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "removing black influence leaves white as sole influence source")
	end)

	it("corner influence reach stays within board bounds", function()
		set_stone_instance(g, "black", 1, "influence_stone", 2)
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . W .",
			". . . . . . . . .",
		})
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . W .",
			". . . . . . . . I",
		})
		assert_territory_ascii(g, {
			". . . . . . . . b",
			". . . . . . . . b",
			". . . . . . . . b",
			". . . . . . . . b",
			". . . . . . . . b",
			". . . . . . . . b",
			". . . . . . . . b",
			". . . . . . . W b",
			"b b b b b b b b B",
		}, "edge influence extends only within valid board coordinates")
	end)

	it("existing basic stone keeps normal reach when influence placed beside it", function()
		set_stone_instance(g, "black", 1, "influence_stone", 1)
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B . . . . . . . W",
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
			"B I . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"B B b b b . w w W",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
		}, "basic stone at (5,1) keeps normal reach; only influence stone at (5,2) gets the bonus")
	end)

	it("white tier1 influence extends reach symmetrically", function()
		set_stone_instance(g, "white", 1, "influence_stone", 1)
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
		test_helper.place_stone_for(g, "white", "influence_stone", {
			"B . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . i",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"B b b b b b w w w",
			"b b b b b w w w w",
			"b b b b w w w w w",
			"b b b w w w w w w",
			"b b w w w w w w W",
			"b b w w w w w w w",
			"b b w w w w w w w",
			"b b w w w w w w w",
			"b b w w w w w w w",
		}, "white tier1 influence reaches further toward isolated black stone")
	end)
end)
