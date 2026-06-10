--- Visual spec: tax_stone (OBJECTS.md #20).
---
--- Stone under test: tax_stone
--- Effect: recurring end-of-turn tax from enemy stones inside qualifying enclosure.
--- Trigger: each owner end_of_turn while tax stone remains on board (not one-shot on placement).
--- Payout per enemy per round: tax_money_per_enemy (money) and tax_points_per_enemy (points).
--- Multiple tax stones in one region do not multiply payout.
--- Nested enclosure rule: innermost owner enclosure containing the tax stone pays.
--- Capture on placement removes enemies before that turn's tax; capture bonus is separate.
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
local set_hand = test_helper.set_hand
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_money = test_helper.assert_player_money
local advance_rounds = test_helper.advance_rounds

local S = P.stone

--- @param capture_count integer
--- @return number
local function capture_bonus_for(capture_count)
	return P.capture_bonus_points(capture_count)
end

describe("tax_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "tax_stone" }, "tax_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("single enemy enclosed in minimal ring pays tax", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W . B . .",
			". . . B . . B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W . B . .",
			". . . B . T B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 1
		local expected_points = S.tax_points_per_enemy * 1
		assert_player_money(g, "black", snap.money + expected_money, "one enemy taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "one enemy taxed")
	end)

	it("four enemies scattered in medium enclosure pay proportional tax", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . B B B B B . .",
			". . B W . W B . .",
			". . B . . . B . .",
			". . B W . W B . .",
			". . B B . B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
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
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 4
		local expected_points = S.tax_points_per_enemy * 4
		assert_player_money(g, "black", snap.money + expected_money, "four scattered enemies taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "four scattered enemies taxed")
	end)

	it("empty enclosure with no enemies pays zero tax", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B B . .",
			". . . B . . B . .",
			". . . B . . B . .",
			". . . B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B B . .",
			". . . B . T B . .",
			". . . B . . B . .",
			". . . B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "no enemies no tax")
		assert_player_points_delta(g, "black", snap, 0, "no enemies no tax")
	end)

	it("two tax stones in same enclosure do not multiply payout", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B B . .",
			". . B W . W B . .",
			". . B . . . B . .",
			". . B T . . B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
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
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 2
		local expected_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + expected_money, "two enemies counted once despite two tax stones")
		assert_player_points_delta(g, "black", snap, expected_points, "payout not doubled by extra tax stone")
	end)

	it("two separate enclosures each with tax stone sum payouts at end of turn", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			"B B B B . . . . .",
			"B W . B . . . . .",
			"B . T B . . . . .",
			"B B B . . . . . .",
			". . . . . . . . .",
			". . . . . . B B B",
			". . . . . . B W .",
			". . . . . . B . .",
			". . . . . . B B B",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			"B B B B . . . . .",
			"B W . B . . . . .",
			"B . T B . . . . .",
			"B B B . . . . . .",
			". . . . . . . . .",
			". . . . . . B B B",
			". . . . . . B W .",
			". . . . . . B T .",
			". . . . . . B B B",
		})
		test_helper.finish_turn(g)
		local per_round_money = S.tax_money_per_enemy * 2
		local per_round_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + per_round_money, "both enclosures taxed same end of turn")
		assert_player_points_delta(g, "black", snap, per_round_points, "1+1 enemies from two regions")
		advance_rounds(g, 1)
		assert_player_money(g, "black", snap.money + per_round_money * 2, "both enclosures taxed again next end of turn")
	end)

	it("three enclosures on board but only those with tax stone pay at end of turn", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			"B B B . . . B B B",
			"B W . B . . B . B",
			"B B B . . . B B B",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B B B B",
			". . . . . B W . .",
			". . . . . B . . .",
			". . . . . B B B .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			"B B B . . . B B B",
			"B W . B . . B . B",
			"B B B . . . B B B",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B B B B",
			". . . . . B W . .",
			". . . . . B T . .",
			". . . . . B B B .",
		})
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 1
		local expected_points = S.tax_points_per_enemy * 1
		assert_player_money(g, "black", snap.money + expected_money, "only bottom enclosure with tax stone pays")
		assert_player_points_delta(g, "black", snap, expected_points, "enemies in other enclosures ignored")
		advance_rounds(g, 1)
		assert_player_money(g, "black", snap.money + expected_money * 2, "tax repeats while stone and enemy remain")
	end)

	it("tax placement capturing sole enclosed enemy pays zero tax that turn", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			"B B B . . . B B B",
			"B W . B . . B . B",
			"B B B . . . B B B",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"B W . B . . . . .",
			"B B B . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			"B B B . . . B B B",
			"B W . B . . B . B",
			"B B B . . . B B B",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"B W T B . . . . .",
			"B B B . . . . . .",
		})
		test_helper.finish_turn(g)
		test_helper.assert_board_cell_empty(g, 8, 2, "enclosed white captured on tax placement")
		assert_player_money(g, "black", snap.money, "no tax money when enemy captured on placement")
		assert_player_points_delta(g, "black", snap, capture_bonus_for(1), "capture bonus only, no tax points")
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "no recurring tax without enclosed enemies")
	end)

	it("captured tax stone pays nothing at end of turn", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W . B . .",
			". . . B . . B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W . B . .",
			". . . B . T B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.capture_stone_at(g, 5, 5, "black")
		local snap = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "captured tax stone inactive")
		assert_player_points_delta(g, "black", snap, 0, "captured tax stone inactive")
	end)

	it("enemy removed from enclosure before payout is excluded", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W W B . .",
			". . . B W . B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		local prisoners_before = g.players.black.prisoners or 0
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W W B . .",
			". . . B W T B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.finish_turn(g)
		test_helper.assert_board_cell_empty(g, 4, 5, "first white of captured group removed")
		test_helper.assert_board_cell_empty(g, 4, 6, "second white of captured group removed")
		test_helper.assert_board_cell_empty(g, 5, 5, "third white of captured group removed")
		assert.are.equal(prisoners_before + 3, g.players.black.prisoners or 0, "three prisoners from capture")
		assert_player_money(g, "black", snap.money, "captured enemies not taxed that turn")
		assert_player_points_delta(g, "black", snap, capture_bonus_for(3), "capture bonus only, no tax points")
		local snap_after_capture = player_score_snapshot(g, "black")
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap_after_capture.money, "no tax on later end of turn without enemies")
		assert_player_points_delta(g, "black", snap_after_capture, 0, "empty enclosure pays zero tax each round")
	end)

	it("black tax stone inside white enclosure pays black nothing", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W W W . . .",
			". . . W . . W . .",
			". . . W W W . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
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
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "wrong color enclosure no tax")
		assert_player_points_delta(g, "black", snap, 0, "wrong color enclosure no tax")
	end)

	it("tax payout repeats each end of turn", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W . B . .",
			". . . B . . B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W . B . .",
			". . . B . T B . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local per_turn_money = S.tax_money_per_enemy * 1
		local per_turn_points = S.tax_points_per_enemy * 1
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money + per_turn_money, "turn one tax")
		assert_player_points_delta(g, "black", snap, per_turn_points, "turn one tax points")
		local snap_after_first = player_score_snapshot(g, "black")
		advance_rounds(g, 1)
		assert_player_money(g, "black", snap.money + per_turn_money * 2, "turn two tax again")
		assert_player_points_delta(g, "black", snap_after_first, per_turn_points, "turn two tax points again")
	end)

	it("corner enclosure using two board edges taxes enclosed enemies", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . B B",
			". . . . . B W . .",
			". . . . . B . W .",
			". . . . . B . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . T B B",
			". . . . . B W . .",
			". . . . . B . W .",
			". . . . . B . . .",
		})
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 2
		local expected_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + expected_money, "two enemies in corner enclosure")
		assert_player_points_delta(g, "black", snap, expected_points, "right+bottom edges complete enclosure")
	end)

	it("side-edge enclosure using left board boundary taxes enemies", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			"B B B B . . . . .",
			"W . . B . . . . .",
			". . . B . . . . .",
			"W . . B . . . . .",
			". B B B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
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
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 2
		local expected_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + expected_money, "two enemies along left edge")
		assert_player_points_delta(g, "black", snap, expected_points, "left board edge completes the wall")
	end)

	it("tax only counts enemies inside its enclosure, not enemies loose on the board", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". W . B B B . . .",
			". . . B W . B . .",
			". . . B . . B . .",
			". . . B B B . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". W . B B B . . .",
			". . . B W . B . .",
			". . . B . T B . .",
			". . . B B B . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 1
		local expected_points = S.tax_points_per_enemy * 1
		assert_player_money(g, "black", snap.money + expected_money, "only enclosed enemy taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "loose enemies on board ignored")
	end)

	it("cluster of four enemy stones inside enclosure all counted", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B B . .",
			". . B W W W B . .",
			". . B W . . B . .",
			". . B . . . B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . B B B B B . .",
			". . B W W W B . .",
			". . B W T . B . .",
			". . B . . . B . .",
			". . B B B B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 4
		local expected_points = S.tax_points_per_enemy * 4
		assert_player_money(g, "black", snap.money + expected_money, "all four clustered enemies taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "enemy cluster fully counted")
	end)

	it("adjacent enclosures sharing a wall stone: each taxes independently", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". B B B B . . . .",
			". B W . B . . . .",
			". B . T B . . . .",
			". B B B B . . . .",
			". B W . B . . . .",
			". B . . B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
		})
		local snap = player_score_snapshot(g, "black")
		place_stone(g, {
			". . . . . . . . .",
			". B B B B . . . .",
			". B W . B . . . .",
			". B . T B . . . .",
			". B B B B . . . .",
			". B W . B . . . .",
			". B . T B . . . .",
			". B B B B . . . .",
			". . . . . . . . .",
		})
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 2
		local expected_points = S.tax_points_per_enemy * 2
		assert_player_money(g, "black", snap.money + expected_money, "one enemy per adjacent region")
		assert_player_points_delta(g, "black", snap, expected_points, "shared wall taxes both sides independently")
	end)

	it("open arc with gap prevents enclosure, tax pays nothing", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B W . . . .",
			". . . . B . . . .",
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
			". . . B W . . . .",
			". . . T B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "open arc = no enclosure")
		assert_player_points_delta(g, "black", snap, 0, "gap in boundary prevents tax")
	end)


	it("outer black-zone enemy taxed while white inner pocket enemies are not", function()
		set_hand(g, "black", { "tax_stone" })
		set_board(g, {
			". . . . . . . . .",
			". . . . . W . . .",
			". . . . . . W . .",
			"B B B B B B . . .",
			". B W . . B . . .",
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
			". B W . T B . . .",
			"W W W W . B . . .",
			". W . W . B . . .",
			". . . W . B . . .",
			". W . W . B . . .",
		})
		test_helper.finish_turn(g)
		local expected_money = S.tax_money_per_enemy * 1
		local expected_points = S.tax_points_per_enemy * 1
		assert_player_money(g, "black", snap.money + expected_money, "one outer black-zone enemy taxed")
		assert_player_points_delta(g, "black", snap, expected_points, "white inner pocket enemies not taxed")
	end)

	it("tax stone placed inside white inner pocket pays zero", function()
		set_hand(g, "black", { "tax_stone" })
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
			". B . . T B . . .",
			"W W W W . B . . .",
			". W . W . B . . .",
			". . . W . B . . .",
			". W . W . B . . .",
		})
		test_helper.finish_turn(g)
		assert_player_money(g, "black", snap.money, "T inside white pocket — no black enclosure")
		assert_player_points_delta(g, "black", snap, 0, "enemies in white inner pocket not taxed by black")
	end)
end)
