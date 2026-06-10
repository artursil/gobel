--- Visual spec: influence_stone (OBJECTS.md #3).
---
--- Stone under test: influence_stone
--- Effect: distance_bonus — reduces the stone's effective Manhattan distance
--- for territory assignment, letting it "reach further" and claim cells that
--- would otherwise belong to the opponent or be neutral.
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
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_territory_ascii = test_helper.assert_territory_ascii

local S = P.stone

--- @param tier integer
--- @return number
local function influence_tier_bonus(tier)
	local key = "influence_t" .. tier
	if S[key] then
		return S[key]
	end
	return P.stone_effect_value("influence_stone", "distance_bonus_tier" .. tier)
		or S.stone_influence_distance_bonus
end

describe("influence_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "influence_stone" }, "influence_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("tier1 on contested row flips midline column to black", function()
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
		}, "tier1 bonus shifts boundary one column past what a basic stone would claim")
	end)

	it("tier2 extends territory further than tier1 on same contested board", function()
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
		}, "tier2 bonus claims one extra column vs tier1")
	end)

	it("tier3 reaches maximum configured distance on contested row", function()
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
		}, "tier3 bonus claims maximum configured extra territory")
	end)

	it("tier ordering: T1 < T2 < T3 in parameters", function()
		local t1 = influence_tier_bonus(1)
		local t2 = influence_tier_bonus(2)
		local t3 = influence_tier_bonus(3)
		assert.is_true(t1 < t2 and t2 < t3, "influence tier bonuses preserve ordering")
	end)

	it("influence breaks tie on equidistant cells in multi-stone board", function()
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
		}, "influence stone tips balance in column 5 from tie to black")
	end)

	it("complex board with white pressure — influence reclaims contested border", function()
		set_stone_instance(g, "black", 1, "influence_stone", 2)
		set_board(g, {
			"B B . . W . . . .",
			"B . . W . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		place_stone(g, {
			"B B . . W . . . .",
			"B . . W . . . . .",
			". . . . . . . . .",
			". . . I . . . . .",
			". . . . . . . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		assert_territory_ascii(g, {
			"B B b w W w w w w",
			"B b . W w w w w w",
			"b b b b b b b b b",
			"b b b B b b b b b",
			"b b b b b b b b b",
			"b b b B b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
		}, "tier2 influence reclaims cells from white despite W pressure in top rows")
	end)

	it("two influence stones on same side stack their reach", function()
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
			"I . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, false)
		assert_territory_ascii(g, {
			"b b b b b . w w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"B b b b b . w w w",
			"b b b b . w w w W",
			"b b b b . w w w w",
			"b b b b . w w w w",
			"b b b b . w w w w",
			"b b b b . w w w w",
		}, "two tier1 stones each extend independently, overlapping claims more territory than one alone")
	end)

	it("opponent nearby still holds adjacent territory despite influence", function()
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
		}, "white stone retains immediate surrounding cells despite adjacent influence")
	end)

	it("captured influence stone reverts territory to basic-stone levels", function()
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
		test_helper.capture_stone_at(g, 5, 1, "white")
		test_helper.finish_turn(g)
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
		}, "captured influence leaves white as sole owner, territory fully reverts")
	end)

	it("edge placement clamps influence halo within board bounds", function()
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

	it("existing basic stone does not gain bonus from nearby influence placement", function()
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
