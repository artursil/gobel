--- Visual spec: money_field_stone (OBJECTS.md #15).
---
--- Stone under test: money_field_stone
--- Effect: on placement, adds money_field_payout when the placed cell is owner-enclosed;
--- otherwise adds zero. One-time placement payout only.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local S = require("spec.parameters_helper").stone

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	M = { color = config.STONE_BLACK, kind = "money_field_stone" },
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
local assert_player_points_delta = test_helper.assert_player_points_delta

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

describe("money_field_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "money_field_stone" }, "money_field_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("money_field_stone enclosure payout", function()
		it("minimal black ring: enclosed placement pays money_field_payout", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B . B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B M B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = S.money_field_payout
			assert_player_money(g, "black", snap.money + expected_delta, "enclosed money field payout")
			assert_player_points_delta(g, "black", snap, 0, "money field does not add points on placement")
		end)

		it("open board placement pays zero", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, blank_board())
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . M . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "open board no money")
		end)

		it("white-owned enclosed cell pays zero to black placer", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . W W W . . . .",
				". . W . . W . . .",
				". . W W W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . W W W . . . .",
				". . W M . W . . .",
				". . W W W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "enemy-owned enclosure no payout to black")
		end)

		it("opponent stone on black ring still allows enclosed payout", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W B B . . .",
				". . . B . B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W B B . . .",
				". . . B M B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = S.money_field_payout
			assert_player_money(g, "black", snap.money + expected_delta, "white on ring ignored for black enclosure")
		end)

		it("edge-connected pocket open to board edge pays zero", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". B B B . . . . .",
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
				". . . M . . . . .",
				". B B B . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "edge-leaking pocket not enclosed")
		end)

		it("completing the ring with money_field_stone encloses before payout", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B . B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B M B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = S.money_field_payout
			assert_player_money(g, "black", snap.money + expected_delta, "completing wall encloses before payout")
		end)

		it("corner pocket using board boundary pays money_field_payout", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				"B B B . . . . . .",
				"B . B . . . . . .",
				"B B B . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				"B B B . . . . . .",
				"B M B . . . . . .",
				"B B B . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = S.money_field_payout
			assert_player_money(g, "black", snap.money + expected_delta, "corner enclosure payout")
		end)

		it("edge-adjacent enclosed pocket pays money_field_payout", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"B B B . . . . . .",
				"B . B . . . . . .",
				"B B B . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"B B B . . . . . .",
				"B M B . . . . . .",
				"B B B . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = S.money_field_payout
			assert_player_money(g, "black", snap.money + expected_delta, "edge enclosure payout")
		end)

		it("two separate black enclosures each pay once", function()
			set_hand(g, "black", { "money_field_stone", "money_field_stone" })
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
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". B B B B . . . .",
				". B M . B . . . .",
				". B B B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B B B .",
				". . . . . B . B .",
				". . . . . B . B .",
				". . . . . B B B .",
			})
			test_helper.place_stone_for(g, "black", "money_field_stone", {
				". B B B B . . . .",
				". B M . B . . . .",
				". B B B B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B B B .",
				". . . . . B M B .",
				". . . . . B . B .",
				". . . . . B B B .",
			})
			local expected_delta = S.money_field_payout * 2
			assert_player_money(g, "black", snap.money + expected_delta, "each separate enclosure pays once")
		end)

		it("two enclosures on board: open gap between rings pays zero", function()
			set_hand(g, "black", { "money_field_stone" })
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
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". B B B B . . . .",
				". B . . B . . . .",
				". B B B B . . . .",
				". . . . M . . . .",
				". . . . . . . . .",
				". . . . . B B B .",
				". . . . . B . B .",
				". . . . . B . B .",
				". . . . . B B B .",
			})
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "gap between enclosures not enclosed")
		end)

		it("white inner pocket inside outer black frame pays zero to black", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . W . . .",
				". . . . . . W . .",
				"B B B B B B . . .",
				". B . . . B . . .",
				"W W W W . B . . .",
				". W . W . B . . .",
				". . . W . B . . .",
				". W . W . B . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . W . . .",
				". . . . . . W . .",
				"B B B B B B . . .",
				". B . . . B . . .",
				"W W W W . B . . .",
				". W M . W . B . . .",
				". . . W . B . . .",
				". W . W . B . . .",
			})
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "opponent pocket inside our frame still white-owned")
		end)

		it("nested black pocket inside outer black wall pays money_field_payout", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . W . . .",
				". . . . . . W . .",
				"B B B B B B . . .",
				"W B W W . B . . .",
				". B . . W B . . .",
				". . . . W B . . .",
				". . . . W B . . .",
				". . . . W B . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . W . . .",
				". . . . . . W . .",
				"B B B B B B . . .",
				"W B W W M B . . .",
				". B . . W B . . .",
				". . . . W B . . .",
				". . . . W B . . .",
				". . . . W B . . .",
			})
			local expected_delta = S.money_field_payout
			assert_player_money(g, "black", snap.money + expected_delta, "inner black pocket inside outer black wall")
		end)

		it("white inner pocket inside outer black wall at same scale pays zero to black", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . W . . .",
				". . . . . . W . .",
				"B B B B B B . . .",
				"W B W W W B . . .",
				". W . . W B . . .",
				". . . . W B . . .",
				". . . . W B . . .",
				". . . . W B . . .",
			})
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . . . . W . . .",
				". . . . . . W . .",
				"B B B B B B . . .",
				"W B W W W B . . .",
				". W . M W B . . .",
				". . . . W B . . .",
				". . . . W B . . .",
				". . . . W B . . .",
			})
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta,
				"M inside white pocket within outer black wall — not black-enclosed")
		end)

		it("large multi-cell enclosure pays flat money_field_payout not per cell", function()
			set_hand(g, "black", { "money_field_stone" })
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
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". . B B B B B . .",
				". . B M . . B . .",
				". . B . . . B . .",
				". . B B B B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local expected_delta = S.money_field_payout
			assert_player_money(g, "black", snap.money + expected_delta, "payout flat regardless of pocket size")
		end)

		it("illegal occupied placement pays nothing", function()
			set_hand(g, "black", { "money_field_stone" })
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
			test_helper.assert_illegal_player_move_with_stone(g, "black", "money_field_stone", 5, 5, "occupied rejects money field")
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "illegal move no money")
		end)

		it("end_of_turn adds no second payout", function()
			set_hand(g, "black", { "money_field_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B . B . . .",
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
				". . . B M B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap_after = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)
			local expected_delta = 0
			assert_player_money(g, "black", snap_after.money + expected_delta, "no recurring money field payout")
		end)

		it("fixture #13 style board: enclosed black cell pays, gap cells do not", function()
			set_hand(g, "black", { "money_field_stone" })
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
				"W M B . . B . . W",
				"B W W B B . . W .",
				". . B W B B W . .",
				"B B . W W W . W B",
				". B B . W . . B .",
			})
			local expected_delta = S.money_field_payout
			assert_player_money(g, "black", snap.money + expected_delta, "enclosed pocket on complex multi-enclosure board")
		end)

		it("fixture #13 style board: open gap cell pays zero", function()
			set_hand(g, "black", { "money_field_stone" })
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
				"W . B . . B . . W",
				"B W W B B . . W .",
				"M . B W B B W . .",
				"B B . W W W . W B",
				". B B . W . . B .",
			})
			local expected_delta = 0
			assert_player_money(g, "black", snap.money + expected_delta, "gap pocket on complex board not enclosed")
		end)
	end)
end)
