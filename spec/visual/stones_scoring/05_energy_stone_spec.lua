--- Visual spec: energy_stone (OBJECTS.md #5).
---
--- Stone under test: energy_stone
--- Effect: add_energy — on placement, adds energy_stone_gain to the placing
--- player's current energy (clamped by energy_max).
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local match_state = require("match_state")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	E = { color = config.STONE_BLACK, kind = "energy_stone" },
	e = { color = config.STONE_WHITE, kind = "energy_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_energy = test_helper.set_energy
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_energy = test_helper.assert_player_energy
local assert_player_energy_max_unchanged = test_helper.assert_player_energy_max_unchanged
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged

local S = P.stone

--- @return number
local function energy_gain()
	return S.energy_stone_gain
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

describe("energy_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "energy_stone" }, "energy_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("placement at center adds configured energy gain", function()
		set_hand(g, "black", { "energy_stone" })
		set_energy(g, "black", 0)
		set_board(g, blank_board())

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . E . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_energy(g, "black", energy_gain(), "energy_stone grants configured gain from zero")
	end)

	it("placement adds gain on top of existing energy", function()
		set_hand(g, "black", { "energy_stone" })
		set_energy(g, "black", 1)
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"E . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_energy(g, "black", snap.energy + energy_gain(), "energy added to existing amount")
	end)

	it("energy clamped at energy_max when placement would exceed cap", function()
		set_hand(g, "black", { "energy_stone" })
		local max_e = match_state.player_for_color(g, "black").resources.energy_max
		set_energy(g, "black", max_e)
		set_board(g, blank_board())

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . E . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_energy(g, "black", max_e, "energy does not exceed max")
	end)

	it("energy_max unchanged after placement", function()
		set_hand(g, "black", { "energy_stone" })
		set_energy(g, "black", 0)
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . E . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_energy_max_unchanged(g, "black", snap, "max energy unchanged by energy_stone")
	end)

	it("placement does not affect points or mult", function()
		set_hand(g, "black", { "energy_stone" })
		set_energy(g, "black", 0)
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . E . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_unchanged(g, "black", snap, "energy_stone does not add points")
	end)

	it("second placement on later turn adds gain again", function()
		set_hand(g, "black", { "energy_stone" })
		set_energy(g, "black", 0)
		set_board(g, blank_board())

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . E . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, false)

		test_helper.finish_turn(g)
		test_helper.pass_turn(g)
		set_hand(g, "black", { "energy_stone" })
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . E E . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_energy(g, "black", snap.energy + energy_gain(), "second placement adds gain independently")
	end)

	it("no passive energy gained from board stone on subsequent turns", function()
		set_hand(g, "black", { "energy_stone" })
		set_energy(g, "black", 0)
		set_board(g, blank_board())

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . E . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		local energy_after_placement = energy_gain()
		test_helper.finish_turn(g)
		test_helper.pass_turn(g)
		test_helper.finish_turn(g)
		test_helper.pass_turn(g)

		assert_player_energy(g, "black", energy_after_placement, "no passive energy ticks from board stone")
	end)

	it("white energy_stone adds energy to white, not black", function()
		set_energy(g, "white", 0)
		set_energy(g, "black", 0)
		set_board(g, blank_board())

		test_helper.place_stone_for(g, "white", "energy_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . e . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_energy(g, "white", energy_gain(), "white gains energy from own placement")
		assert_player_energy(g, "black", 0, "black unaffected by white energy_stone")
	end)

	it("illegal placement on occupied cell gives no energy", function()
		set_hand(g, "black", { "energy_stone" })
		set_energy(g, "black", 0)
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

		test_helper.assert_illegal_player_move_with_stone(g, "black", "energy_stone", 5, 5, "occupied rejects energy_stone")

		assert_player_energy(g, "black", 0, "no energy on rejected placement")
	end)

	it("placement on board with existing stones still grants full gain", function()
		set_hand(g, "black", { "energy_stone" })
		set_energy(g, "black", 0)
		set_board(g, {
			"B . . . . . . . W",
			". . . . . . . . .",
			". . B . . . W . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . W . . . B . .",
			". . . . . . . . .",
			"W . . . . . . . B",
		})

		place_stone(g, {
			"B . . . . . . . W",
			". . . . . . . . .",
			". . B . . . W . .",
			". . . . . . . . .",
			". . . . E . . . .",
			". . . . . . . . .",
			". . W . . . B . .",
			". . . . . . . . .",
			"W . . . . . . . B",
		})

		assert_player_energy(g, "black", energy_gain(), "energy gain unaffected by surrounding stones")
	end)
end)
