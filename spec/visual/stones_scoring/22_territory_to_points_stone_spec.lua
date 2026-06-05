--- Visual spec: territory_to_points_stone (OBJECTS.md #22).
---
--- Stone under test: territory_to_points_stone
--- End-of-turn trigger: determines territory owner at stone cell,
--- computes min(S.t2p_cap, floor(owner_territory / S.t2p_divisor)),
--- adds payout to that owner's points. Payout tracks live territory each turn.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	Y = { color = config.STONE_BLACK, kind = "territory_to_points_stone" },
	y = { color = config.STONE_WHITE, kind = "territory_to_points_stone" },
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
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_territory_ascii = test_helper.assert_territory_ascii

local S = P.stone

describe("territory_to_points_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "territory_to_points_stone" }, "territory_to_points_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("basic payout from territory", function()
		it("single Y at center owns entire board, payout hits cap", function()
			set_hand(g, "black", { "territory_to_points_stone" })
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
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_territory_ascii(g, {
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b b Y b b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
			}, "single stone claims all territory")

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = S.t2p_cap
			assert_player_points_delta(g, "black", snap, expected_delta, "large territory hits t2p cap")
		end)

		it("Y on split board with W gives moderate payout below cap", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". Y . . . . . . .",
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
				"b Y b b b b b b b",
				"w b b b b b b b b",
				"W w w w w w w w w",
				"w w w w w w w w w",
				"w w w w w w w w w",
				"w w w w w w w w w",
				"w w w w w w w w w",
				"w w w w w w w w w",
			}, "black owns top rows, white dominates below")

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_delta, "moderate territory below cap")
		end)

		it("Y surrounded by white ring has zero black territory, pays zero", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W . W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W Y W . . .",
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_delta, "zero or negligible territory pays zero")
		end)
	end)

	describe("payout goes to territory owner at stone cell", function()
		it("black Y on black-owned cell pays black", function()
			set_hand(g, "black", { "territory_to_points_stone" })
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

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_delta, "payout to black as cell territory owner")
		end)

		it("white y stone on white-owned cell pays white", function()
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

			test_helper.place_stone_for(g, "white", "territory_to_points_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_territory_ascii(g, {
				"w w w w w w w w w",
				"w w w w w w w w w",
				"w w w w w w w w w",
				"w w w w w w w w w",
				"w w w w y w w w w",
				"w w w w w w w w w",
				"w w w w w w w w w",
				"w w w w w w w w w",
				"w w w w w w w w w",
			}, "white y claims entire board for white")

			local territory_white = test_helper.count_territory_cells(g, "white")
			local snap = player_score_snapshot(g, "white")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_white / S.t2p_divisor))
			assert_player_points_delta(g, "white", snap, expected_delta, "payout to white as cell territory owner")
		end)

		it("black Y and white y on same board each pay their respective side", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". Y . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.place_stone_for(g, "white", "territory_to_points_stone", {
				". . . . . . . . .",
				". Y . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . y . . . .",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local territory_white = test_helper.count_territory_cells(g, "white")
			local snap_black = player_score_snapshot(g, "black")
			local snap_white = player_score_snapshot(g, "white")
			test_helper.finish_turn(g)

			local expected_black = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			local expected_white = math.min(S.t2p_cap, math.floor(territory_white / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap_black, expected_black, "Y pays black from black territory")
			assert_player_points_delta(g, "white", snap_white, expected_white, "y pays white from white territory")
		end)
	end)

	describe("captured stone stops paying", function()
		it("Y captured before end of turn pays nothing", function()
			set_hand(g, "black", { "territory_to_points_stone" })
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

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.capture_stone_at(g, 6, 5, "black")
			test_helper.assert_board_cell_empty(g, 6, 5, "Y removed from board")

			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			assert_player_points_delta(g, "black", snap, 0, "captured Y pays nothing")
		end)

		it("Y pays first turn, captured before second turn pays nothing on second", function()
			set_hand(g, "black", { "territory_to_points_stone" })
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
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_t1 = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_t1 = math.min(S.t2p_cap, math.floor(territory_t1 / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_t1, "first turn payout")

			test_helper.capture_stone_at(g, 5, 5, "black")
			local snap2 = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			assert_player_points_delta(g, "black", snap2, 0, "captured Y silent on second turn")
		end)
	end)

	describe("multiple stones multiply payouts", function()
		it("two Y stones on all-black board each pay cap independently", function()
			set_hand(g, "black", { "territory_to_points_stone", "territory_to_points_stone" })
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
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local per_stone_payout = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			local expected_delta = 2 * per_stone_payout
			assert_player_points_delta(g, "black", snap, expected_delta, "two Y stones double the payout")
		end)

		it("two Y stones on moderate territory: both use same territory total", function()
			set_hand(g, "black", { "territory_to_points_stone", "territory_to_points_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". Y . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)

			place_stone(g, {
				". . . . . . . . .",
				". Y . . . . . . .",
				". . Y . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local per_stone_payout = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			local expected_delta = 2 * per_stone_payout
			assert_player_points_delta(g, "black", snap, expected_delta, "both stones use same territory count")
		end)
	end)

	describe("multi-round payout tracking", function()
		it("Y pays every end of turn while it remains on board", function()
			set_hand(g, "black", { "territory_to_points_stone" })
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
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_t1 = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local payout_t1 = math.min(S.t2p_cap, math.floor(territory_t1 / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, payout_t1, "turn 1 payout")

			local territory_t2 = test_helper.count_territory_cells(g, "black")
			local snap2 = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local payout_t2 = math.min(S.t2p_cap, math.floor(territory_t2 / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap2, payout_t2, "turn 2 payout repeats")
		end)

		it("opponent places W stones, black territory shrinks, payout decreases", function()
			set_hand(g, "black", { "territory_to_points_stone" })
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
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_t1 = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local payout_t1 = math.min(S.t2p_cap, math.floor(territory_t1 / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, payout_t1, "turn 1 full board payout")

			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_t2 = test_helper.count_territory_cells(g, "black")
			local snap2 = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local payout_t2 = math.min(S.t2p_cap, math.floor(territory_t2 / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap2, payout_t2, "turn 2 payout from reduced territory")
			assert.is_true(territory_t2 < territory_t1, "territory shrunk after opponent W placed")
		end)

		it("multiple W placements progressively shrink black territory and payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
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
				". Y . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_t1 = test_helper.count_territory_cells(g, "black")
			local snap1 = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local payout_t1 = math.min(S.t2p_cap, math.floor(territory_t1 / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap1, payout_t1, "turn 1 full board")

			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". Y . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_t2 = test_helper.count_territory_cells(g, "black")
			local snap2 = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local payout_t2 = math.min(S.t2p_cap, math.floor(territory_t2 / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap2, payout_t2, "turn 2 with one W")

			set_hand(g, "black", { "stone_basic" })
			place_stone(g, {
				". . . . . . . . .",
				". Y . . . . . . .",
				". B . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". Y . . . . . . .",
				". B . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_t3 = test_helper.count_territory_cells(g, "black")
			local snap3 = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local payout_t3 = math.min(S.t2p_cap, math.floor(territory_t3 / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap3, payout_t3, "turn 3 with two W")
			assert.is_true(territory_t3 < territory_t2, "territory further reduced")
		end)
	end)

	describe("enclosure and influence territory", function()
		it("Y inside own ring enclosure with corner W gets payout from combined territory", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, {
				"W . . . . . . . W",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B . B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . W",
			})

			place_stone(g, {
				"W . . . . . . . W",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B Y B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . W",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_delta, "enclosure + influence territory combined")
		end)

		it("Y inside small enclosure with heavy white presence gets small payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, {
				"W W W W W W W W W",
				"W . . . . . . . W",
				"W . . B B B . . W",
				"W . . B . B . . W",
				"W . . B B B . . W",
				"W . . . . . . . W",
				"W . . . . . . . W",
				"W . . . . . . . W",
				"W W W W W W W W W",
			})

			place_stone(g, {
				"W W W W W W W W W",
				"W . . . . . . . W",
				"W . . B B B . . W",
				"W . . B Y B . . W",
				"W . . B B B . . W",
				"W . . . . . . . W",
				"W . . . . . . . W",
				"W . . . . . . . W",
				"W W W W W W W W W",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_delta, "small enclosure in white sea pays small amount")
		end)

		it("Y on case 04 contested board with neutral cells gets payout from actual black territory only", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, {
				"B B . . W . . . .",
				"B . . W . . . . .",
				". W W . . . . . .",
				"W W . . . . . . .",
				". . . . W W . . .",
				". . . B . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				"B B . . W . . . .",
				"B . . W . . . . .",
				". W W . . . . . .",
				"W W . . . Y . . .",
				". . . . W W . . .",
				". . . B . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_delta, "neutral cells excluded from territory total")
		end)

		it("Y on multi-enclosure board (case 05) pays from complex territory total", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, {
				". . . W . . W . .",
				". B . W . . W . .",
				"B . W B B B W . .",
				". W B W . W B W B",
				". W B . W . B W .",
				". . W B B B . W .",
				". B . W . . . W .",
				"W W W . . . . . W",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . W . . W . .",
				". B . W . . W . .",
				"B . W B B B W . .",
				". W B W . W B W B",
				". W B Y W . B W .",
				". . W B B B . W .",
				". B . W . . . W .",
				"W W W . . . . . W",
				". . . . . . . . .",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_delta, "complex multi-enclosure territory drives payout")
		end)
	end)

	describe("edge and corner placement", function()
		it("Y at corner (1,1) still triggers payout from territory", function()
			set_hand(g, "black", { "territory_to_points_stone" })
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
				"Y . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_delta, "corner Y still triggers payout")
		end)

		it("Y at edge (1,5) with W nearby splits territory", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
			})

			place_stone(g, {
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
			})

			local territory_black = test_helper.count_territory_cells(g, "black")
			local snap = player_score_snapshot(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap, expected_delta, "edge Y pays from partial territory")
		end)
	end)

	describe("no placement trigger — only end of turn", function()
		it("Y payout is not applied at placement, only at end of turn", function()
			set_hand(g, "black", { "territory_to_points_stone" })
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

			local snap_before = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . Y . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			}, false)

			assert_player_points_unchanged(g, "black", snap_before, "no points added at placement time")

			local territory_black = test_helper.count_territory_cells(g, "black")
			test_helper.finish_turn(g)

			local expected_delta = math.min(S.t2p_cap, math.floor(territory_black / S.t2p_divisor))
			assert_player_points_delta(g, "black", snap_before, expected_delta, "points added only after end of turn")
		end)
	end)
end)
