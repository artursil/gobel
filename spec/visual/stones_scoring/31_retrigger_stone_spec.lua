--- Visual spec: retrigger_stone (OBJECTS.md #31).
---
--- Stone under test: retrigger_stone
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	E = { color = config.STONE_BLACK, kind = "escalating_points_stone" },
	H = { color = config.STONE_BLACK, kind = "high_power_money_loss_stone" },
	R = { color = config.STONE_BLACK, kind = "retrigger_stone" },
	w = { color = config.STONE_BLACK, kind = "wall" },
	h = { color = config.STONE_WHITE, kind = "high_power_money_loss_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_money = test_helper.set_money
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_money = test_helper.assert_player_money
local assert_stone_stored_value = test_helper.assert_stone_stored_value

local S = P.stone

--- @return number
local function eps_round_points()
	return S.eps_round_points or 3
end

--- @return number
local function eps_capture_multiplier()
	return S.eps_capture_multiplier or 2
end

--- @param bank number
--- @return number
local function eps_capture_transfer(bank)
	return eps_capture_multiplier() * bank
end

--- @return number
local function hpml_points()
	return S.hpml_points_gain or P.stone_effect_value("high_power_money_loss_stone", "add_points") or 12
end

--- @return number
local function hpml_plus_mult()
	return S.hpml_plus_mult_gain or P.stone_effect_value("high_power_money_loss_stone", "add_mult") or 6
end

--- @return number
local function hpml_money_loss()
	return S.hpml_money_loss or 8
end

--- @return number
local function retrigger_fallback_points()
	return S.retrigger_fallback_points or 1
end

local STONE_IDS = { "escalating_points_stone", "high_power_money_loss_stone", "retrigger_stone" }

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

describe("retrigger_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"retrigger_stone"}, "retrigger_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("retrigger_stone", function()
		it("retrigger_stone scenario 1: replays prior same-turn wall payout", function()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . w w w w . .",
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
				". . . w w w w w .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local snap_after_wall = player_score_snapshot(g, "black")
			assert_player_points_delta(g, "black", snap, P.wall_points(5), "wall pays once")
			set_hand(g, "black", { "retrigger_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . w w w w w .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap_after_wall, P.wall_points(5), "retrigger repeats wall once")
		end)

		it("retrigger_stone scenario 2: non-retriggerable effect uses fallback", function()
			set_hand(g, "black", { "retrigger_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap, retrigger_fallback_points(), "fallback on excluded target")
		end)

		it("retrigger_stone scenario 3: empty same-turn history uses fallback", function()
			set_hand(g, "black", { "retrigger_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, retrigger_fallback_points(), "fallback with no history")
		end)

		it("retrigger_stone scenario 4: opponent effect is not targeted for black retrigger", function()
			set_board(g, blank_board())
			test_helper.place_stone_for(g, "white", "stone_basic", {
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
			set_hand(g, "black", { "retrigger_stone" })
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap, retrigger_fallback_points(), "white effect not replayed")
		end)

		it("retrigger_stone scenario 5: prior retrigger excluded uses fallback", function()
			set_hand(g, "black", { "retrigger_stone", "retrigger_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local snap_after_first = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . R R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap_after_first, retrigger_fallback_points(), "second does not replay retrigger")
		end)

		it("retrigger_stone scenario 6: replay occurs exactly once per placement", function()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . w w w w . .",
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
				". . . w w w w w .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local snap = player_score_snapshot(g, "black")
			set_hand(g, "black", { "retrigger_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . w w w w w .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap, P.wall_points(5), "single replay increment")
		end)

		it("retrigger_stone scenario 7: illegal retrigger placement pays nothing", function()
			set_hand(g, "black", { "retrigger_stone" })
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
			test_helper.assert_illegal_player_move_with_stone(g, "black", "retrigger_stone", 5, 5, "illegal retrigger")
			assert_player_points_delta(g, "black", snap, 0, "illegal no fallback")
		end)

		it("retrigger_stone scenario 8: uses own prior effect when both players acted", function()
			set_hand(g, "black", { "wall" })
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . w w w w . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . w w w w . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			set_hand(g, "black", { "retrigger_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . w w w w . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap, P.wall_points(4), "replays black wall not white basic")
		end)

		it("retrigger_stone scenario 9: edge placement fallback unchanged", function()
			set_hand(g, "black", { "retrigger_stone" })
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
				". . . . . . . . .",
				"R . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, retrigger_fallback_points(), "edge fallback")
		end)

		it("retrigger_stone scenario 10: two retriggers with empty history each pay fallback once", function()
			set_hand(g, "black", { "retrigger_stone", "retrigger_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . R R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap, 2 * retrigger_fallback_points(), "two fallbacks")
		end)
	end)
end)
