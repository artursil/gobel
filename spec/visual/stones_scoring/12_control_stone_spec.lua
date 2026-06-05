--- Visual spec: control_stone (OBJECTS.md #12).
---
--- Stone under test: control_stone
--- Effect: sets override_owner on orthogonal neighbor cells to the stone's color.
--- Override has highest precedence in territory resolution:
---   override > enclosure > influence
---
--- NOTE: control_stone is currently unimplemented (stub). These tests document
--- intended behavior and will pass once the effect is wired up.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	O = { color = config.STONE_BLACK, kind = "control_stone" },
	o = { color = config.STONE_WHITE, kind = "control_stone" },
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
local assert_territory_ascii = test_helper.assert_territory_ascii

local S = P.stone

describe("control_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "control_stone" }, "control_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("flips white-influenced cells to black on contested midline", function()
		set_hand(g, "black", { "control_stone" })
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

		assert_territory_ascii(g, {
			"B b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b .",
			"b b b b b b b . w",
			"b b b b b b . w w",
			"b b b b b . w w w",
			"b b b b . w w w w",
			"b b b . w w w w w",
			"b b . w w w w w W",
		}, "baseline: influence splits board diagonally")

		place_stone(g, {
			"B . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . O . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})

		assert_territory_ascii(g, {
			"B b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b .",
			"b b b b b b b . w",
			"b b b b b b b w w",
			"b b b b b B b w w",
			"b b b b . b w w w",
			"b b b . w w w w w",
			"b b . w w w w w W",
		}, "control_stone overrides 4 orthogonal neighbors to black, flipping white cells")
	end)

	it("white control_stone steals black-influenced territory", function()
		set_board(g, {
			". . . . . . . . .",
			". B . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"b b b b b b b b b",
			"b B b b b b b b b",
			"w b b b b b b b b",
			"W w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "baseline: B owns top rows, W owns bottom via influence")

		test_helper.place_stone_for(g, "white", "control_stone", {
			". . . . . . . . .",
			". B . . . . . . .",
			". o . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"b b b b b b b b b",
			"b B w b b b b b b",
			"w W w w b b b b b",
			"W w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "white control at (3,2) overrides (2,2), (3,1), (3,3), (4,2) to white")
	end)

	it("override beats enclosure: flips cell inside opponent's sealed ring", function()
		set_hand(g, "black", { "control_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . W W W W W . .",
			". . W . . . W . .",
			". . W . . . W . .",
			". . W W W W W . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w W W W W W w w",
			"w w W w w w W w w",
			"w w W w w w W w w",
			"w w W W W W W w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "baseline: white ring encloses interior, white owns entire board")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . W W W W W . .",
			". . W . . . W . .",
			". . W . O . W . .",
			". . W W W W W . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w W W W W W w w",
			"w w W w b w W w w",
			"w w W b B b W w w",
			"w w W W W W W w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "control override > enclosure: 4 neighbors flip from white to black inside ring")
	end)

	it("only orthogonal neighbors affected, diagonals unchanged", function()
		set_hand(g, "black", { "control_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . W . . . .",
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
			". . . . W . . . .",
			". . . . . . . . .",
			". . . O . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w W w w w w",
			"w w w b w w w w w",
			"w w w b B b w w w",
			"w w w b w w w w w",
			"w w w w w w w w w",
		}, "diagonal cells (5,4), (5,6), (7,4), (7,6) remain white-influenced, not overridden")
	end)

	it("opposing controls on shared neighbor: cell becomes neutral", function()
		set_hand(g, "black", { "control_stone" })
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
			". . . . O . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, false)

		test_helper.place_stone_for(g, "white", "control_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . O o . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . b w . . .",
			". . . b B W w . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, "cell (5,5) contested by both → neutral '.', non-shared neighbors keep own color")
	end)

	it("same-color overlap: two adjacent black controls reinforce", function()
		set_hand(g, "black", { "control_stone" })
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
			". . . . O O . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, false)

		assert_territory_ascii(g, {
			"b b b b b b b . w",
			"b b b b b b b . w",
			"b b b b b b . w w",
			"b b b b b b b w w",
			"b b b b B B b W w",
			"b b b b b b b w w",
			"b b b b b b . w w",
			"b b b b b b b . w",
			"b b b b b b b . w",
		}, "overlapping black overrides union to black, no cancellation")
	end)

	it("captured control_stone: override disappears, territory reverts to influence", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . O . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.capture_stone_at(g, 5, 5, "black")
		test_helper.finish_turn(g)

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
		}, "after capture, override gone: white owns entire board via influence from (5,9)")
	end)

	it("corner placement: only 2 in-bounds neighbors overridden", function()
		set_hand(g, "black", { "control_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})

		place_stone(g, {
			"O . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})

		assert_territory_ascii(g, {
			"B b b b b b b . w",
			"b b b b b b . w w",
			"b b b b b . w w w",
			"b b b b . w w w w",
			"b b b . w w w w w",
			"b b . w w w w w w",
			"b . w w w w w w w",
			". w w w w w w w w",
			"w w w w w w w w W",
		}, "corner (1,1): only (1,2) and (2,1) overridden to black")
	end)

	it("edge placement: only 3 in-bounds neighbors overridden", function()
		set_hand(g, "black", { "control_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"O . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})

		assert_territory_ascii(g, {
			"b b b b b b b . w",
			"b b b b b b . w w",
			"b b b b b . w w w",
			"b b b b b . w w w",
			"B b b b . w w w w",
			"b b b b . w w w w",
			"b b b b b . w w w",
			"b b b b b b . w w",
			"b b b b b b b . W",
		}, "left-edge (5,1): neighbors (4,1), (5,2), (6,1) overridden, no (5,0)")
	end)

	it("control deep in opponent territory: creates island of own color", function()
		set_board(g, {
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"W w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "baseline: white owns entire board")

		set_hand(g, "black", { "control_stone" })
		place_stone(g, {
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . O . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"W w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w b w w w w",
			"w w w b B b w w w",
			"w w w w b w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "control creates 4-cell black island surrounded by white territory")
	end)

	it("control overrides enclosure but not the enclosure itself", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . W W W W W . .",
			". . W . . . W . .",
			". . W . . . W . .",
			". . W . . . W . .",
			". . W W W W W . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		set_hand(g, "black", { "control_stone" })
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . W W W W W . .",
			". . W . O . W . .",
			". . W . . . W . .",
			". . W . . . W . .",
			". . W W W W W . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w W W W W W w w",
			"w w W b B b W w w",
			"w w W b b w W w w",
			"w w W w w w W w w",
			"w w W W W W W w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "4 neighbors overridden to black; remaining enclosed cells stay white")
	end)

	it("control on complex board: flips contested midline cells", function()
		set_hand(g, "black", { "control_stone" })
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

		assert_territory_ascii(g, {
			"B B w w W w w w w",
			"B w w W w w w w w",
			"w W W w w b b b b",
			"W W w w . B b b b",
			"w w w . W W w w w",
			"w . b B . w w w w",
			"w . b b . w w w w",
			"w . b b . w w w w",
			"w . b b . w w w w",
		}, "baseline: complex influence with neutral '.' cells")

		place_stone(g, {
			"B B . . W . . . .",
			"B . . W . . . . .",
			". W W . . . . . .",
			"W W . . O B . . .",
			". . . . W W . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"B B w w W w w w w",
			"B w w W w w w w w",
			"w W W w b b b b b",
			"W W w b B B b b b",
			"w w w b W W w w w",
			"w . b B . w w w w",
			"w . b b . w w w w",
			"w . b b . w w w w",
			"w . b b . w w w w",
		}, "control at (4,5) flips neutral cell and surrounding influenced cells to black")
	end)

	it("multiple control stones spread across board: each creates local override zone", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})
		set_hand(g, "black", { "control_stone" })

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . O . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . O . .",
			". . . . . . . . .",
			". . . . . . . . W",
		}, false)

		test_helper.place_stone_for(g, "black", "control_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . O . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . O . .",
			". . . . . . . . .",
			". . . . . . . . W",
		})

		assert_territory_ascii(g, {
			"b b b b b b b . w",
			"b b b b b b . w w",
			"b b B b b . w w w",
			"b b b b . w w w w",
			"b b b . w w w w w",
			"b b . w w w b w w",
			"b . w w w b B b w",
			". w w w w w b w w",
			"w w w w w w w . W",
		}, "two control stones each override their local 4 neighbors independently")
	end)

	it("control placed adjacent to opponent stone: override applies to empty neighbors only", function()
		set_hand(g, "black", { "control_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . W . . . .",
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
			". . . . W . . . .",
			". . . . O . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w b W b w w w",
			"w w w b B b w w w",
			"w w w w b w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
			"w w w w w w w w w",
		}, "override only on empty cells; W stone at (4,5) unaffected, (4,4) and (4,6) flipped")
	end)

	it("control vs control: non-overlapping zones coexist", function()
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
		set_hand(g, "black", { "control_stone" })

		place_stone(g, {
			". . . . . . . . .",
			". . O . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, false)

		test_helper.place_stone_for(g, "white", "control_stone", {
			". . . . . . . . .",
			". . O . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . o . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			". . b . . . . . .",
			". b B b . . . . .",
			". . b . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . w . .",
			". . . . . w W w .",
			". . . . . . w . .",
			". . . . . . . . .",
		}, "black zone top-left, white zone bottom-right, rest neutral")
	end)

	it("control overrides tie-break: neutral cell becomes owned", function()
		set_hand(g, "black", { "control_stone" })
		set_board(g, {
			"B . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"B b b b . w w w W",
			"b b b . . . w w w",
			"b b . . . . . w w",
			"b . . . . . . . w",
			". . . . . . . . .",
			"b . . . . . . . w",
			"b b . . . . . w w",
			"b b b . . . w w w",
			"b b b b . w w w w",
		}, "baseline: diagonal of neutral '.' cells where influence ties")

		place_stone(g, {
			"B . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . O . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"B b b b . w w w W",
			"b b b . . . w w w",
			"b b . . . . . w w",
			"b . . . b . . . w",
			". . . b B b . . .",
			"b . . . b . . . w",
			"b b . . . . . w w",
			"b b b . . . w w w",
			"b b b b . w w w w",
		}, "control at (5,5) overrides neutral neighbors to black, breaks the tie")
	end)

	it("white control inside black enclosure: override beats enclosure for inner cells", function()
		set_board(g, {
			". . . . . . . . .",
			". B B B B B B . .",
			". B . . . . B . .",
			". B . . . . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		test_helper.place_stone_for(g, "white", "control_stone", {
			". . . . . . . . .",
			". B B B B B B . .",
			". B . . . . B . .",
			". B . o . . B . .",
			". B . . . . B . .",
			". B B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_territory_ascii(g, {
			"b b b b b b b b b",
			"b B B B B B B b b",
			"b B b w b b B b b",
			"b B w W w b B b b",
			"b B b w b b B b b",
			"b B B B B B B b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
			"b b b b b b b b b",
		}, "white control inside black enclosure: 4 neighbors flip to white, rest stay black")
	end)

	it("stability: second resolve produces same territory as first", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . O . o . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local first = test_helper.territory_ownership_ascii(g)
		test_helper.finish_turn(g)
		local second = test_helper.territory_ownership_ascii(g)
		assert.are.equal(first, second, "contested territory stable across turn boundary")
	end)
end)
