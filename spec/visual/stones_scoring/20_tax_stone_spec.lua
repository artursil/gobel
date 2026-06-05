--- Visual spec: tax_stone (OBJECTS.md #20).
---
--- Stone under test: tax_stone
--- Effect: end-of-turn tax payout from enemy stones inside qualifying enclosure.
--- Payout per enemy: tax_money_per_enemy (money) and tax_points_per_enemy (points).
--- Multiple tax stones in one region do not multiply payout.
--- Nested enclosure rule: innermost owner enclosure containing the tax stone pays.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	T = { color = config.STONE_BLACK, kind = "tax_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_board = test_helper.set_board
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_money = test_helper.assert_player_money
local assert_territory_ascii = test_helper.assert_territory_ascii

local S = P.stone

describe("tax_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({"tax_stone"}, "tax_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("single enemy enclosed in minimal ring pays tax", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W T B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 1
		local expected_points = S.tax_points_per_enemy * 1
		assert_player_money(g, "black", snap.money + expected_money, "one enemy taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "one enemy taxed")
	end)

	it("four enemies scattered in medium enclosure pay proportional tax", function()
		set_board(g, {
			". . . . . . . . .",
			". . B B B B B . .",
			". . B W . W B . .",
			". . B . . . B . .",
			". . B W . W B . .",
			". . B B T B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 4
		local expected_points = S.tax_points_per_enemy * 4
		assert_player_money(g, "black", snap.money + expected_money, "four scattered enemies taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "four scattered enemies taxed")
	end)

	it("empty enclosure with no enemies pays zero tax", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B B . .",
			". . . B . . B . .",
			". . . B . . T . .",
			". . . B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "no enemies no tax")
		assert_player_points_delta(g, "black", snap, 0, "no enemies no tax")
	end)

	it("two tax stones in same enclosure do not multiply payout", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B B . .",
			". . B W . W B . .",
			". . B . . . B . .",
			". . B T . T B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 2
		local expected_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + expected_money, "two enemies counted once despite two tax stones")
		assert_player_points_delta(g, "black", snap, expected_points, "payout not doubled by extra tax stone")
	end)

	it("two separate enclosures each with tax stone sum payouts", function()
		set_board(g, {
			"B B B B . . . . .",
			"B W T B . . . . .",
			"B B B . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . B B B",
			". . . . . . B W T",
			". . . . . . B B B",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 2
		local expected_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + expected_money, "1+1 enemies from two regions")
		assert_player_points_delta(g, "black", snap, expected_points, "separate enclosures sum independently")
	end)

	it("three enclosures on board but only the one with tax stone pays", function()
		set_board(g, {
			"B B B . . . B B B",
			"B W B . . . B W B",
			"B B B . . . B B B",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"B W T B . . . . .",
			"B B B . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 1
		local expected_points = S.tax_points_per_enemy * 1
		assert_player_money(g, "black", snap.money + expected_money, "only enclosure with tax stone pays")
		assert_player_points_delta(g, "black", snap, expected_points, "enemies in other enclosures ignored")
	end)

	it("captured tax stone pays nothing at end of turn", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W T B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.capture_stone_at(g, 5, 6, "black")
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "captured tax stone inactive")
		assert_player_points_delta(g, "black", snap, 0, "captured tax stone inactive")
	end)

	it("enemy removed from enclosure before payout is excluded", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W T B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.capture_stone_at(g, 5, 5, "white")
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "removed enemy not taxed")
		assert_player_points_delta(g, "black", snap, 0, "removed enemy not taxed")
	end)

	it("black tax stone inside white enclosure pays black nothing", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W W W . . .",
			". . . W . T W . .",
			". . . W W W . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "wrong color enclosure no tax")
		assert_player_points_delta(g, "black", snap, 0, "wrong color enclosure no tax")
	end)

	it("tax payout repeats each end of turn", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W T B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		local per_turn_money = S.tax_money_per_enemy * 1
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money + per_turn_money, "turn one tax")
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money + per_turn_money * 2, "turn two tax again")
	end)

	it("corner enclosure using two board edges taxes enclosed enemies", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . T B B B",
			". . . . . B W . .",
			". . . . . B . W .",
			". . . . . B . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 2
		local expected_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + expected_money, "two enemies in corner enclosure")
		assert_player_points_delta(g, "black", snap, expected_points, "right+bottom edges complete enclosure")
	end)

	it("side-edge enclosure using left board boundary taxes enemies", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"W . . B . . . . .",
			". . . B . . . . .",
			"W . . B . . . . .",
			"T B B B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 2
		local expected_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + expected_money, "two enemies along left edge")
		assert_player_points_delta(g, "black", snap, expected_points, "left board edge completes the wall")
	end)

	it("tax only counts enemies inside its enclosure, not enemies loose on the board", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". W . B B B . . .",
			". . . B W T B W .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 1
		local expected_points = S.tax_points_per_enemy * 1
		assert_player_money(g, "black", snap.money + expected_money, "only enclosed enemy taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "loose enemies on board ignored")
	end)

	it("cluster of four enemy stones inside enclosure all counted", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B B . .",
			". . B W W W B . .",
			". . B W . . T . .",
			". . B . . . B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 4
		local expected_points = S.tax_points_per_enemy * 4
		assert_player_money(g, "black", snap.money + expected_money, "all four clustered enemies taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "enemy cluster fully counted")
	end)

	it("adjacent enclosures sharing a wall stone: each taxes independently", function()
		set_board(g, {
			". . . . . . . . .",
			". B B B B . . . .",
			". B W . B . . . .",
			". B . . B . . . .",
			". B B T B . . . .",
			". B W . B . . . .",
			". B . . B . . . .",
			". B B T B . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 2
		local expected_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + expected_money, "one enemy per adjacent region")
		assert_player_points_delta(g, "black", snap, expected_points, "shared wall taxes both sides independently")
	end)

	it("open arc with gap prevents enclosure, tax pays nothing", function()
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W . . . .",
			". . . T B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "open arc = no enclosure")
		assert_player_points_delta(g, "black", snap, 0, "gap in boundary prevents tax")
	end)

	it("large irregular enclosure with six scattered enemies", function()
		set_board(g, {
			". . . . . . . . .",
			". B B B B B B B .",
			". B W . . . W B .",
			". B . . W . . B .",
			". B . W . . . B .",
			". B . . . W . B .",
			". T W . . . . B .",
			". B B B B B B B .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 6
		local expected_points = S.tax_points_per_enemy * 6
		assert_player_money(g, "black", snap.money + expected_money, "six scattered enemies taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "large enclosure counts all enemies")
	end)

	it("top-edge enclosure using board boundary as wall taxes enemy", function()
		set_board(g, {
			"B . W . . B . . .",
			"B . . . . B . . .",
			"B . . . . B . . .",
			"B B B T B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 1
		local expected_points = S.tax_points_per_enemy * 1
		assert_player_money(g, "black", snap.money + expected_money, "top edge enclosure one enemy")
		assert_player_points_delta(g, "black", snap, expected_points, "board boundary completes the wall")
	end)

	it("complex multi-region board taxes only enemies in enclosure with tax stone", function()
		set_board(g, {
			". . . W . . W . .",
			". B . W . . W . .",
			"B . W B B B W . .",
			". W B W . W B W B",
			". W B . W . B W .",
			". . W B T B . W .",
			". B . W . . . W .",
			"W W W . . . . . W",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 3
		local expected_points = S.tax_points_per_enemy * 3
		assert_player_money(g, "black", snap.money + expected_money, "three enemies in contested enclosure")
		assert_player_points_delta(g, "black", snap, expected_points, "complex multi-region taxes correctly")
	end)
end)
