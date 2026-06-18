--- Visual spec: copper_stone (OBJECTS.md #30).
---
--- Stone under test: copper_stone
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	N = { color = config.STONE_BLACK, kind = "enclosure_stone" },
	M = { color = config.STONE_BLACK, kind = "money_field_stone" },
	O = { color = config.STONE_BLACK, kind = "control_stone" },
	o = { color = config.STONE_WHITE, kind = "control_stone" },
	C = { color = config.STONE_BLACK, kind = "copper_stone" },
	c = { color = config.STONE_WHITE, kind = "copper_stone" },
	T = { color = config.STONE_BLACK, kind = "tower_stone" },
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
local assert_player_money = test_helper.assert_player_money
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_territory_ascii = test_helper.assert_territory_ascii
local assert_territory_values_ascii = test_helper.assert_territory_values_ascii

local S = P.stone

--- @return number
local function enclosure_multiplier()
	return S.enclosure_stone_multiplier
		or P.stone_effect_value("enclosure_stone", "enclosure_multiplier")
		or 2
end

--- @return number
local function money_field_payout()
	return S.money_field_payout or P.stone_effect_value("money_field_stone", "add_money") or 3
end

--- @return number
local function copper_threshold()
	return S.copper_threshold or 3
end

--- @return number
local function copper_threshold_bonus()
	return S.copper_threshold_plus_mult_bonus
		or P.stone_effect_value("copper_stone", "add_mult")
		or 2
end

--- @return number
local function copper_base_points()
	return S.copper_base_points or P.stone_points("copper_stone") or 0
end

--- @param value number
--- @return string
local function territory_value_char(value)
	return tostring(math.floor(value + 0.5))
end

local doubled = territory_value_char(enclosure_multiplier())
local base_val = territory_value_char(1)

--- Placeholder letters for assert_territory_values_ascii (see test_helper opts.values).
local TV_OPTS = { values = { d = doubled, b = base_val } }

local STONE_IDS = { "enclosure_stone", "control_stone", "money_field_stone", "copper_stone" }

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

describe("copper_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"copper_stone"}, "copper_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("copper_stone", function()
		it("copper_stone scenario 1: below threshold grants no plus_mult bonus", function()
			set_hand(g, "black", { "copper_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . C C . . . .",
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
				". . . C C C . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_plus_mult_delta(g, "black", snap, 0, "third copper below threshold")
		end)

		it("copper_stone scenario 2: reaching threshold on placement adds bonus", function()
			set_hand(g, "black", { "copper_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . C C C . . .",
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
				". . . C C C C . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_plus_mult_delta(g, "black", snap, copper_threshold_bonus(), "fourth copper hits threshold")
		end)

		it("copper_stone scenario 3: above threshold still grants bonus on new copper", function()
			set_hand(g, "black", { "copper_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . C C C C . .",
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
				". . . C C C C C .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_plus_mult_delta(g, "black", snap, copper_threshold_bonus(), "above threshold still pays")
		end)

		it("copper_stone scenario 4: base points apply regardless of threshold", function()
			set_hand(g, "black", { "copper_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, copper_base_points(), "base copper points always apply")
		end)

		it("copper_stone scenario 5: capture dropping below threshold removes next bonus", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . C C C C . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.capture_stone_at(g, 4, 3, "black")
			set_hand(g, "black", { "copper_stone" })
			local snap = player_score_snapshot(g, "black")
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . C C C . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_plus_mult_delta(g, "black", snap, 0, "after capture count below threshold")
		end)

		it("copper_stone scenario 6: white copper threshold is owner-scoped", function()
			set_hand(g, "white", { "copper_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . c c c . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "white")
			test_helper.place_stone_for(g, "white", "copper_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . c c c c . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_plus_mult_delta(g, "white", snap, copper_threshold_bonus(), "white copper threshold")
		end)

		it("copper_stone scenario 7: sequential placements re-check count each time", function()
			set_hand(g, "black", { "copper_stone", "copper_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . C . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local snap2 = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . C C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_plus_mult_delta(g, "black", snap, 0, "first copper no threshold")
			assert_player_plus_mult_delta(g, "black", snap2, 0, "second copper still below threshold")
		end)

		it("copper_stone scenario 8: hand copper does not count toward threshold", function()
			set_hand(g, "black", { "copper_stone", "copper_stone", "copper_stone", "copper_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_plus_mult_delta(g, "black", snap, 0, "only on-board copper counts")
		end)

		it("copper_stone scenario 9: illegal placement leaves count unchanged", function()
			set_hand(g, "black", { "copper_stone" })
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
			test_helper.assert_illegal_player_move_with_stone(g, "black", "copper_stone", 5, 5, "illegal copper")
			assert_player_plus_mult_delta(g, "black", snap, 0, "illegal copper no bonus")
		end)

		it("copper_stone scenario 10: black copper count ignores white board copper", function()
			set_hand(g, "black", { "copper_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . c c c . . .",
				". . . . . . . . .",
				". . . C C C . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . c c c . . .",
				". . . . . . . . .",
				". . . C C C C . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_plus_mult_delta(g, "black", snap, copper_threshold_bonus(), "white copper not in black count")
		end)
	end)
end)
