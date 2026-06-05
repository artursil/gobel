--- Visual spec: high_power_money_loss_stone (OBJECTS.md #29).
---
--- Stone under test: high_power_money_loss_stone
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

describe("high_power_money_loss_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"high_power_money_loss_stone"}, "high_power_money_loss_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("high_power_money_loss_stone", function()
		it("high_power_money_loss_stone scenario 1: sufficient money applies gains and loss", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 20)
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . H . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "black", snap, hpml_points(), "points gain")
			assert_player_plus_mult_delta(g, "black", snap, hpml_plus_mult(), "plus_mult gain")
			assert_player_money(g, "black", 20 - hpml_money_loss(), "money loss applied")
		end)

		it("high_power_money_loss_stone scenario 2: money exactly loss amount reaches zero", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", hpml_money_loss())
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . H . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_money(g, "black", 0, "exact loss to zero")
		end)

		it("high_power_money_loss_stone scenario 3: below loss amount clamps money at floor", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 5)
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . H . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_money(g, "black", 0, "clamp at zero")
			assert_player_points_delta(g, "black", snap, hpml_points(), "gains still apply")
		end)

		it("high_power_money_loss_stone scenario 4: net money includes other same-turn money effects", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 10)
			test_helper.grant_money(g, "black", 4, "other effect")
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . H . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_money(g, "black", 10 + 4 - hpml_money_loss(), "combined money deltas")
		end)

		it("high_power_money_loss_stone scenario 5: illegal placement applies no package", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 10)
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
			test_helper.assert_illegal_player_move_with_stone(g, "black", "high_power_money_loss_stone", 4, 4, "illegal")
			assert_player_money(g, "black", 10, "money unchanged")
			assert_player_points_delta(g, "black", snap, 0, "no points")
		end)

		it("high_power_money_loss_stone scenario 6: two turns each apply full package", function()
			set_hand(g, "black", { "high_power_money_loss_stone", "high_power_money_loss_stone" })
			set_money(g, "black", 30)
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . H . . . . .",
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
				". . . H H . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap, 2 * hpml_points(), "two placements points")
			assert_player_money(g, "black", 30 - 2 * hpml_money_loss(), "two placements money loss")
		end)

		it("high_power_money_loss_stone scenario 7: white placement affects white only", function()
			set_hand(g, "white", { "high_power_money_loss_stone" })
			test_helper.set_money(g, "white", 15)
			set_board(g, blank_board())
			local snap_white = player_score_snapshot(g, "white")
			local snap_black = player_score_snapshot(g, "black")
			test_helper.place_stone_for(g, "white", "high_power_money_loss_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . h . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_points_delta(g, "white", snap_white, hpml_points(), "white points")
			assert_player_points_delta(g, "black", snap_black, 0, "black untouched")
		end)

		it("high_power_money_loss_stone scenario 8: retrigger replays gain and loss together", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 20)
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . H . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			local snap = player_score_snapshot(g, "black")
			set_hand(g, "black", { "retrigger_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . H R . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)
			assert_player_points_delta(g, "black", snap, 2 * hpml_points(), "retrigger doubles points component")
			assert_player_money(g, "black", 20 - 2 * hpml_money_loss(), "retrigger doubles money loss")
		end)

		it("high_power_money_loss_stone scenario 9: end_of_turn adds no extra penalty", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 12)
			set_board(g, blank_board())
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . H . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap_after = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)
			assert_player_money(g, "black", snap_after.money, "no delayed money loss")
		end)

		it("high_power_money_loss_stone scenario 10: total score uses updated points mult and money", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 10)
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . H . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_player_total_score_reflects_state(g, "black", snap, "score uses post-placement state")
		end)
	end)
end)
