--- Visual spec: territory control rounds grid maintenance.
---
--- Each case: initial stone board, seeded control grid (explicit ASCII),
--- one placement that shifts territory slightly, then assert final control ASCII
--- after ``complete_full_round`` (opponent pass → end-of-round tick).
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")

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
local set_control = test_helper.set_territory_control_rounds_ascii
local place_stone = test_helper.place_stone
local place_stone_for = test_helper.place_stone_for
local complete_full_round = test_helper.complete_full_round
local assert_control = test_helper.assert_territory_control_rounds_ascii
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each

local ZERO_ROW = "+0 +0 +0 +0 +0 +0 +0 +0 +0"
local ZERO_ROWS = {}
for i = 1, config.BOARD_SIZE do
	ZERO_ROWS[i] = ZERO_ROW
end

describe("territory_control_rounds (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("delayed start: first black ownership round stays +0, second round increments to +1", function()
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
		set_control(g, ZERO_ROWS)
		set_hand(g, "black", { "stone_basic" })
		set_hand(g, "white", { "stone_basic" })
		place_stone(g, {
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
		complete_full_round(g)
		assert_control(g, {
			"## +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
			"+0 +0 +0 +0 +0 +0 +0 +0 +0",
		}, "delayed start on newly owned cells")
		place_stone(g, {
			"B B . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		complete_full_round(g)
		assert_control(g, {
			"## ## +1 +1 +1 +1 +1 +1 +1",
			"+1 +1 +1 +1 +1 +1 +1 +1 +1",
			"+1 +1 +1 +1 +1 +1 +1 +1 +1",
			"+1 +1 +1 +1 +1 +1 +1 +1 +1",
			"+1 +1 +1 +1 +1 +1 +1 +1 +1",
			"+1 +1 +1 +1 +1 +1 +1 +1 +1",
			"+1 +1 +1 +1 +1 +1 +1 +1 +1",
			"+1 +1 +1 +1 +1 +1 +1 +1 +1",
			"+1 +1 +1 +1 +1 +1 +1 +1 +1",
		}, "second round increments delayed-start cells to +1")
	end)

	it("black pocket +2 increments to +3 when enclosure holds after wall extension", function()
		set_board(g, {
			". . . . . . . . .",
			". . B B B . . . .",
			". . B . B . . . .",
			". . B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		set_control(g, {
			"+1 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 ## ## ## +2 +2 +2 +2",
			"+2 +2 ## +4 ## +2 +2 +2 +2",
			"+2 +2 ## ## ## +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
		})
		set_hand(g, "black", { "stone_basic" })
		place_stone(g, {
			". . . . . . . . .",
			". . B B B . . . .",
			". . B . B B . . .",
			". . B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		complete_full_round(g)
		assert_control(g, {
			"+2 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 ## ## ## +3 +3 +3 +3",
			"+3 +3 ## +5 ## ## +3 +3 +3",
			"+3 +3 ## ## ## +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
		}, "continuing black streak across all black-owned territory")
	end)

	it("filling pocket with stone clears streak cells to ##", function()
		set_board(g, {
			". . . . . . . . .",
			". . B B B . . . .",
			". . B . B . . . .",
			". . B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		set_control(g, {
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 ## ## ## +2 +2 +2 +2",
			"+2 +2 ## +2 ## +2 +2 +2 +2",
			"+2 +2 ## ## ## +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
			"+2 +2 +2 +2 +2 +2 +2 +2 +2",
		})
		set_hand(g, "black", { "stone_basic" })
		place_stone(g, {
			". . . . . . . . .",
			". . B B B . . . .",
			". . B B B . . . .",
			". . B B B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		complete_full_round(g)
		assert_control(g, {
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 ## ## ## +3 +3 +3 +3",
			"+3 +3 ## ## ## +3 +3 +3 +3",
			"+3 +3 ## ## ## +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
		}, "stone-occupied cells show ##")
	end)

	it("white -2 streak increments to -3 when white territory holds", function()
		set_board(g, {
			". . . . . . . . W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		set_control(g, {
			"-2 -2 -2 -2 -2 -2 -2 -2 ##",
			"-2 -2 -2 -2 -2 -2 -2 -2 -2",
			"-2 -2 -2 -2 -2 -2 -2 -2 -2",
			"-2 -2 -2 -2 -2 -2 -2 -2 -2",
			"-2 -2 -2 -2 -2 -2 -2 -2 -2",
			"-2 -2 -2 -2 -2 -2 -2 -2 -2",
			"-2 -2 -2 -2 -2 -2 -2 -2 -2",
			"-2 -2 -2 -2 -2 -2 -2 -2 -2",
			"-2 -2 -2 -2 -2 -2 -2 -2 -2",
		})
		set_hand(g, "white", { "stone_basic" })
		place_stone_for(g, "white", "stone_basic", {
			". . . . . . . W W",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		complete_full_round(g)
		assert_control(g, {
			"-3 -3 -3 -3 -3 -3 -3 ## ##",
			"-3 -3 -3 -3 -3 -3 -3 -3 -3",
			"-3 -3 -3 -3 -3 -3 -3 -3 -3",
			"-3 -3 -3 -3 -3 -3 -3 -3 -3",
			"-3 -3 -3 -3 -3 -3 -3 -3 -3",
			"-3 -3 -3 -3 -3 -3 -3 -3 -3",
			"-3 -3 -3 -3 -3 -3 -3 -3 -3",
			"-3 -3 -3 -3 -3 -3 -3 -3 -3",
			"-3 -3 -3 -3 -3 -3 -3 -3 -3",
		}, "continuing white streak across all white-owned territory")
	end)

	it("black +2 resets to +0 when white placement makes cell contested", function()
		set_board(g, {
			". . . . . . . . .",
			". . B . . . . W .",
			". . B . . . . . W",
			". . B . . . . W .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		set_control(g, {
			"+2 +2 +2 +2 +2 -2 -2 -2 -2",
			"+2 +2 ## +2 +2 -2 -2 ## -2",
			"+2 +2 ## +2 +2 -2 -2 -2 ##",
			"+2 +2 ## +2 +2 -2 -2 ## -2",
			"+2 +2 +2 +2 +2 -2 -2 -2 -2",
			"+2 +2 +2 +2 +2 -2 -2 -2 -2",
			"+2 +2 +2 +2 +2 -2 -2 -2 -2",
			"+2 +2 +2 +2 +2 -2 -2 -2 -2",
			"+2 +2 +2 +2 +2 -2 -2 -2 -2",
		})
		set_hand(g, "white", { "stone_basic" })
		place_stone_for(g, "white", "stone_basic", {
			". . . . . . . . .",
			". . B W . . . W .",
			". . B . . . . . W",
			". . B . . . . W .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		complete_full_round(g)
		assert_control(g, {
			"+3 +3 +3 +0 +0 -3 -3 -3 -3",
			"+3 +3 ## ## +0 -3 -3 ## -3",
			"+3 +3 ## +0 +0 -3 -3 -3 ##",
			"+3 +3 ## +3 +3 -3 -3 ## -3",
			"+3 +3 +3 +3 +3 -3 -3 -3 -3",
			"+3 +3 +3 +3 +3 -3 -3 -3 -3",
			"+3 +3 +3 +3 +3 -3 -3 -3 -3",
			"+3 +3 +3 +3 +3 -3 -3 -3 -3",
			"+3 +3 +3 +3 +3 -3 -3 -3 -3",
		}, "owner flip / contested reset")
	end)

	it("dual pockets increment independently after local wall extension", function()
		set_board(g, {
			". . . . . . . . .",
			". B B . . . B B .",
			". B . . . . . B .",
			". B B . . . B B .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		set_control(g, {
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 ## ## +3 +3 +3 ## ## +3",
			"+3 ## +3 +3 +3 +3 +1 ## +3",
			"+3 ## ## +3 +3 +3 ## ## +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
			"+3 +3 +3 +3 +3 +3 +3 +3 +3",
		})
		set_hand(g, "black", { "stone_basic" })
		place_stone(g, {
			". . . . . . . . .",
			". B B B . . . B B .",
			". B . . . . . . B .",
			". B B . . . B B .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		complete_full_round(g)
		assert_control(g, {
			"+4 +4 +4 +4 +4 +4 +4 +4 +4",
			"+4 ## ## ## +4 +4 ## ## +4",
			"+4 ## +4 +4 +4 +4 +2 ## +4",
			"+4 ## ## +4 +4 +4 ## ## +4",
			"+4 +4 +4 +4 +4 +4 +4 +4 +4",
			"+4 +4 +4 +4 +4 +4 +4 +4 +4",
			"+4 +4 +4 +4 +4 +4 +4 +4 +4",
			"+4 +4 +4 +4 +4 +4 +4 +4 +4",
			"+4 +4 +4 +4 +4 +4 +4 +4 +4",
		}, "each pocket increments independently while outer territory ticks too")
	end)
end)
