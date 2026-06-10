--- Visual spec: high_power_money_loss_stone (OBJECTS.md #29).
---
--- Stone under test: high_power_money_loss_stone (letters H / h).
--- Effect: on placement only — add hpml_points_gain and hpml_plus_mult_gain,
--- subtract hpml_money_loss (clamped at money floor). No recurring end_of_turn effects.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local match_state = require("match_state")
local S = require("spec.parameters_helper").stone

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	H = { color = config.STONE_BLACK, kind = "high_power_money_loss_stone" },
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
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_plus_mult_unchanged = test_helper.assert_player_plus_mult_unchanged
local assert_player_money = test_helper.assert_player_money
local assert_player_total_score = test_helper.assert_player_total_score
local advance_rounds = test_helper.advance_rounds

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
		assert_stone_ids_registered_in_content({ "high_power_money_loss_stone" }, "high_power_money_loss_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("high_power_money_loss_stone placement tradeoff", function()
		it("placement with sufficient money applies points mult and money loss", function()
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
			local expected_points_delta = S.hpml_points_gain
			local expected_mult_delta = S.hpml_plus_mult_gain
			local expected_money = snap.money - S.hpml_money_loss
			assert_player_points_delta(g, "black", snap, expected_points_delta, "points gain on placement")
			assert_player_plus_mult_delta(g, "black", snap, expected_mult_delta, "plus_mult gain on placement")
			assert_player_money(g, "black", expected_money, "money loss on placement")
		end)

		it("money exactly hpml_money_loss reaches zero", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", S.hpml_money_loss)
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
			local expected_money = 0
			assert_player_money(g, "black", expected_money, "exact loss to zero")
		end)

		it("money below hpml_money_loss clamps at floor but gains still apply", function()
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
			local expected_money = 0
			local expected_points_delta = S.hpml_points_gain
			local expected_mult_delta = S.hpml_plus_mult_gain
			assert_player_money(g, "black", expected_money, "clamp at zero")
			assert_player_points_delta(g, "black", snap, expected_points_delta, "points gain despite clamp")
			assert_player_plus_mult_delta(g, "black", snap, expected_mult_delta, "plus_mult gain despite clamp")
		end)

		it("zero money still receives scoring gains on placement", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 0)
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
			local expected_points_delta = S.hpml_points_gain
			local expected_mult_delta = S.hpml_plus_mult_gain
			local expected_money = 0
			assert_player_points_delta(g, "black", snap, expected_points_delta, "points at zero money")
			assert_player_plus_mult_delta(g, "black", snap, expected_mult_delta, "plus_mult at zero money")
			assert_player_money(g, "black", expected_money, "money stays at floor")
		end)

		it("same-turn grant_money nets with hpml_money_loss", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 10)
			test_helper.grant_money(g, "black", 4, "other same-turn money")
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
			local expected_money = 10 + 4 - S.hpml_money_loss
			assert_player_money(g, "black", expected_money, "combined same-turn money deltas")
		end)

		it("illegal occupied placement applies no package", function()
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
			test_helper.assert_illegal_player_move_with_stone(g, "black", "high_power_money_loss_stone", 5, 5, "occupied rejects high power money loss")
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "money unchanged")
			assert_player_points_delta(g, "black", snap, expected_delta, "no points")
			assert_player_plus_mult_delta(g, "black", snap, expected_delta, "no plus_mult")
		end)

		it("second placement on later turn applies full package again", function()
			set_hand(g, "black", { "high_power_money_loss_stone" })
			set_money(g, "black", 30)
			set_board(g, blank_board())
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
			test_helper.finish_turn(g)
			test_helper.pass_turn(g)
			set_hand(g, "black", { "high_power_money_loss_stone" })
			local snap = player_score_snapshot(g, "black")
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
			})
			local expected_points_delta = S.hpml_points_gain
			local expected_mult_delta = S.hpml_plus_mult_gain
			local expected_money = snap.money - S.hpml_money_loss
			assert_player_points_delta(g, "black", snap, expected_points_delta, "second placement adds points")
			assert_player_plus_mult_delta(g, "black", snap, expected_mult_delta, "second placement adds plus_mult")
			assert_player_money(g, "black", expected_money, "second placement subtracts money")
		end)

		it("white placement affects white only", function()
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
			local expected_points_delta = S.hpml_points_gain
			local expected_delta = 0
			assert_player_points_delta(g, "white", snap_white, expected_points_delta, "white points")
			assert_player_points_delta(g, "black", snap_black, expected_delta, "black untouched")
		end)

		it("advance_rounds after placement adds no extra points", function()
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
			advance_rounds(g, 1)
			local expected_delta = 0
			assert_player_points_unchanged(g, "black", snap_after, "no recurring points")
		end)

		it("advance_rounds after placement adds no extra plus_mult", function()
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
			advance_rounds(g, 1)
			assert_player_plus_mult_unchanged(g, "black", snap_after, "no recurring plus_mult")
		end)

		it("advance_rounds after placement adds no extra money loss", function()
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
			advance_rounds(g, 1)
			local expected_delta = 0
			assert_player_money(g, "black", snap_after.money + expected_delta, "no recurring money loss")
		end)

		it("multiple advance_rounds leave placement package unchanged", function()
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
			})
			local snap_after = player_score_snapshot(g, "black")
			advance_rounds(g, 3)
			local expected_delta = 0
			assert_player_points_unchanged(g, "black", snap_after, "points stable across rounds")
			assert_player_plus_mult_unchanged(g, "black", snap_after, "plus_mult stable across rounds")
			assert_player_money(g, "black", snap_after.money + expected_delta, "money stable across rounds")
		end)

		it("pre-seeded stone on board triggers nothing on advance_rounds", function()
			set_money(g, "black", 20)
			set_board(g, {
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
			local snap = player_score_snapshot(g, "black")
			advance_rounds(g, 2)
			local expected_delta = 0
			assert_player_points_delta(g, "black", snap, expected_delta, "set_board alone pays no points")
			assert_player_plus_mult_delta(g, "black", snap, expected_delta, "set_board alone pays no plus_mult")
			assert_player_money(g, "black", snap.money + expected_delta, "set_board alone pays no money change")
		end)

		it("total score reflects post-placement points and plus_mult", function()
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
			local player = match_state.player_for_color(g, "black")
			local expected_total = player.score.turn_bonus
				* player.score.territory
				* player.score.points
				* player.score.plus_mult
				* player.score.x_mult
			assert_player_total_score(g, "black", expected_total, "score uses post-placement state")
		end)
	end)
end)
