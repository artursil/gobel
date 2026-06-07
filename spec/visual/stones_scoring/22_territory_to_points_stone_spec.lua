--- Visual spec: territory_to_points_stone (OBJECTS.md #22).
---
--- Stone under test: territory_to_points_stone (letter Y).
--- Boards from spec/visual/territory_integration_spec.lua.
--- Payout uses territory map **before** placement recomputes territory.
--- Each case uses one initial board (case 01 also uses case 02 board for neutral/opponent
--- because the case 01 layout has only black influence). place_stone matches set_board + Y.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local spec_helper = require("spec.spec_helper")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	Y = { color = config.STONE_BLACK, kind = "territory_to_points_stone" },
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

local S = P.stone

--- @param territory_count integer
--- @return integer
local function t2p_payout(territory_count)
	return math.min(S.t2p_cap, math.floor(territory_count / S.t2p_divisor))
end

--- @param board_rows table
--- @return integer black
--- @return integer white
local function pre_placement_territory_counts(board_rows)
	local b = spec_helper.parse_board_ascii(board_rows)
	local black = spec_helper.liberty_points(b, config.STONE_BLACK)
	local white = spec_helper.liberty_points(b, config.STONE_WHITE)
	return black, white
end

describe("territory_to_points_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "territory_to_points_stone" }, "territory_to_points_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("case 01: single black in center influence", function()
		local BOARD = {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}

		local BOARD_MIRROR = {
			". . . . . . . . .",
			". B . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}

		it("own territory: black receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local black_territory = pre_placement_territory_counts(BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				"Y . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "black", snap, t2p_payout(black_territory), "black-owned cell (1,1)")
			assert_player_points_unchanged(g, "white", snap, "white unchanged")
		end)

		it("opponent territory: white receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD_MIRROR)
			local _, white_territory = pre_placement_territory_counts(BOARD_MIRROR)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". B . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				"Y . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "white", snap, t2p_payout(white_territory), "white-owned cell (5,1)")
			assert_player_points_unchanged(g, "black", snap, "black unchanged")
		end)
	end)

	describe("case 02: mirrored center tie", function()
		local BOARD = {
			". . . . . . . . .",
			". B . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}

		it("own territory: black receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local black_territory = pre_placement_territory_counts(BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				"Y . . . . . . . .",
				". B . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "black", snap, t2p_payout(black_territory), "black-owned cell (1,1)")
			assert_player_points_unchanged(g, "white", snap, "white unchanged")
		end)

		it("opponent territory: white receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local _, white_territory = pre_placement_territory_counts(BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . . . . . . .",
				". B . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . .",
				"Y . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "white", snap, t2p_payout(white_territory), "white-owned cell (5,1)")
			assert_player_points_unchanged(g, "black", snap, "black unchanged")
		end)
	end)

	describe("case 03: black ring with single empty center", function()
		local BOARD = {
			"W . . . . . . . W",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . B . B . . .",
			". . . B B B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			"W . . . . . . . W",
		}

		it("own territory: black receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local black_territory = pre_placement_territory_counts(BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				"W . . . . . . . W",
				". . . . . . . . .",
				". . . B B B . . .",
				". Y . B . B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . W",
			})
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "black", snap, t2p_payout(black_territory), "black-owned cell (4,2)")
			assert_player_points_unchanged(g, "white", snap, "white unchanged")
		end)

		it("neutral territory: no payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				"W . . . . . . . W",
				". . . . . . . . .",
				". . . B B B . . .",
				"Y . . B . B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . W",
			})
			test_helper.finish_turn(g)
			assert_player_points_unchanged(g, "black", snap, "contested cell (4,1) pays black nothing")
			assert_player_points_unchanged(g, "white", snap, "contested cell (4,1) pays white nothing")
		end)

		it("opponent territory: white receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local _, white_territory = pre_placement_territory_counts(BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				"W Y . . . . . . W",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B . B . . .",
				". . . B B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				"W . . . . . . . W",
			})
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "white", snap, t2p_payout(white_territory), "white-owned cell (1,2)")
			assert_player_points_unchanged(g, "black", snap, "black unchanged")
		end)
	end)

	describe("case 04: white edge pressure top-left", function()
		local BOARD = {
			"B B . . W . . . .",
			"B . . W . . . . .",
			". W W . . . . . .",
			"W W . . . B . . .",
			". . . . W W . . .",
			". . . B . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}

		it("own territory: black receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local black_territory = pre_placement_territory_counts(BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				"B B . . W . . . .",
				"B . . W . . . . .",
				". W W . . . . . .",
				"W W . . . B . . .",
				". . . . W W . . .",
				". . Y B . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "black", snap, t2p_payout(black_territory), "black-owned cell (6,4)")
			assert_player_points_unchanged(g, "white", snap, "white unchanged")
		end)

		it("neutral territory: no payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				"B B . . W . . . .",
				"B . . W . . . . .",
				". W W . . . . . .",
				"W W . . . B . . .",
				". . . Y W W . . .",
				". . . B . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_player_points_unchanged(g, "black", snap, "contested cell (5,4) pays black nothing")
			assert_player_points_unchanged(g, "white", snap, "contested cell (5,4) pays white nothing")
		end)

		it("opponent territory: white receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local _, white_territory = pre_placement_territory_counts(BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				"B B Y . W . . . .",
				"B . . W . . . . .",
				". W W . . . . . .",
				"W W . . . B . . .",
				". . . . W W . . .",
				". . . B . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "white", snap, t2p_payout(white_territory), "white-owned cell (1,3)")
			assert_player_points_unchanged(g, "black", snap, "black unchanged")
		end)
	end)

	describe("case 05: multiple enclosures", function()
		local BOARD = {
			". . . W . . W . .",
			". B . W . . W . .",
			"B . W B B B W . .",
			". W B W . W B W B",
			". W B . W . B W .",
			". . W B B B . W .",
			". B . W . . . W .",
			"W W W . . . . . W",
			". . . . . . . . .",
		}

		it("own territory: black receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local black_territory = pre_placement_territory_counts(BOARD)
			local snap = player_score_snapshot(g, "black")
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
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "black", snap, t2p_payout(black_territory), "black-owned cell (5,4)")
			assert_player_points_unchanged(g, "white", snap, "white unchanged")
		end)

		it("neutral territory: no payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . W . . W . .",
				". B . W . . W . .",
				"B . W B B B W . .",
				". W B W . W B W B",
				". W B . W . B W .",
				". . W B B B . W .",
				". B . W Y . . W .",
				"W W W . . . . . W",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_player_points_unchanged(g, "black", snap, "contested cell (7,5) pays black nothing")
			assert_player_points_unchanged(g, "white", snap, "contested cell (7,5) pays white nothing")
		end)

		it("opponent territory: white receives payout", function()
			set_hand(g, "black", { "territory_to_points_stone" })
			set_board(g, BOARD)
			local _, white_territory = pre_placement_territory_counts(BOARD)
			local snap = player_score_snapshot(g, "black")
			place_stone(g, {
				". . . W . . W . .",
				". B . W . . W . .",
				"B . W B B B W . .",
				". W B W . W B W B",
				". W B . W . B W .",
				". . W B B B . W .",
				". B . W . . . W .",
				"W W W Y . . . . W",
				". . . . . . . . .",
			})
			test_helper.finish_turn(g)
			assert_player_points_delta(g, "white", snap, t2p_payout(white_territory), "white-owned cell (8,4)")
			assert_player_points_unchanged(g, "black", snap, "black unchanged")
		end)
	end)
end)
