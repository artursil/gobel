--- Visual spec: points_stone (OBJECTS.md #2).
---
--- Stone under test: points_stone
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	["2"] = { color = config.STONE_BLACK, kind = "points_stone" },
	["@"] = { color = config.STONE_WHITE, kind = "points_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_stone_instance = test_helper.set_stone_instance
local set_board = test_helper.set_board
local place_stone = test_helper.place_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_player_points_delta = test_helper.assert_player_points_delta
local assert_player_points_unchanged = test_helper.assert_player_points_unchanged
local assert_player_plus_mult_unchanged = test_helper.assert_player_plus_mult_unchanged

local S = P.stone

--- @param tier integer
--- @return number
local function points_stone_tier_payout(tier)
	local key = "points_stone_t" .. tier
	if S[key] then
		return S[key]
	end
	return P.stone_effect_value("points_stone", "add_points_tier" .. tier)
		or P.stone_effect_value("points_stone", "add_points")
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

describe("points_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "points_stone" }, "points_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	it("center tier1 placement adds configured tier1 points", function()
		set_stone_instance(g, "black", 1, "points_stone", 1)
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . 2 . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, points_stone_tier_payout(1), "tier1 payout")
	end)

	it("corner tier2 placement adds configured tier2 points", function()
		set_stone_instance(g, "black", 1, "points_stone", 2)
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
			"2 . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, points_stone_tier_payout(2), "tier2 payout")
	end)

	it("edge tier3 placement adds configured tier3 points", function()
		set_stone_instance(g, "black", 1, "points_stone", 3)
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
			". . . . . . . 2 .",
		})

		assert_player_points_delta(g, "black", snap, points_stone_tier_payout(3), "tier3 payout")
	end)

	it("upgraded hand instance pays upgraded tier on placement", function()
		set_stone_instance(g, "black", 1, "points_stone", 1)
		set_stone_instance(g, "black", 1, "points_stone", 2)
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . 2 . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, points_stone_tier_payout(2), "upgrade before placement uses tier2")
	end)

	it("existing points_stone on board does not re-score on second placement", function()
		set_stone_instance(g, "black", 1, "points_stone", 1)
		set_board(g, blank_board())
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . 2 . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		test_helper.finish_turn(g)
		test_helper.pass_turn(g)
		set_hand(g, "black", { "points_stone" })
		set_stone_instance(g, "black", 1, "points_stone", 3)
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . 2 2 . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, points_stone_tier_payout(3), "only newly placed stone scores")
	end)

	it("hand slot two tier3 instance pays tier3 on placement", function()
		set_hand(g, "black", { "points_stone", "points_stone" })
		set_stone_instance(g, "black", 1, "points_stone", 1)
		set_stone_instance(g, "black", 2, "points_stone", 3)
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . 2 . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, points_stone_tier_payout(3), "slot2 tier3 payout")
	end)

	it("placement adds points only without changing plus_mult", function()
		set_stone_instance(g, "black", 1, "points_stone", 2)
		set_board(g, blank_board())
		local snap = player_score_snapshot(g, "black")

		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . 2 . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "black", snap, points_stone_tier_payout(2), "tier2 points only")
		assert_player_plus_mult_unchanged(g, "black", snap, "points_stone does not add plus_mult")
	end)

	it("white placement affects white only", function()
		set_hand(g, "white", { "points_stone" })
		set_stone_instance(g, "white", 1, "points_stone", 2)
		set_board(g, blank_board())
		local snap_white = player_score_snapshot(g, "white")
		local snap_black = player_score_snapshot(g, "black")

		test_helper.place_stone_for(g, "white", "points_stone", {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . @ . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})

		assert_player_points_delta(g, "white", snap_white, points_stone_tier_payout(2), "white gains tier2")
		assert_player_points_unchanged(g, "black", snap_black, "black unchanged by white placement")
	end)

	it("opponent pass after placement adds no extra points_stone payout", function()
		set_stone_instance(g, "black", 1, "points_stone", 3)
		set_board(g, blank_board())
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . 2 . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap_after = player_score_snapshot(g, "black")

		test_helper.pass_turn(g)

		assert_player_points_unchanged(g, "black", snap_after, "opponent pass does not re-trigger points_stone")
	end)

	it("finish turn adds no extra points_stone payout", function()
		set_stone_instance(g, "black", 1, "points_stone", 3)
		set_board(g, blank_board())
		place_stone(g, {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . 2 . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local snap_after = player_score_snapshot(g, "black")

		test_helper.finish_turn(g)

		assert_player_points_unchanged(g, "black", snap_after, "no end_of_turn points from points_stone")
	end)

	it("illegal placement on occupied cell adds zero points", function()
		set_stone_instance(g, "black", 1, "points_stone", 2)
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

		test_helper.assert_illegal_player_move_with_stone(g, "black", "points_stone", 4, 4, "occupied rejects points_stone")

		assert_player_points_unchanged(g, "black", snap, "illegal points_stone has no payout")
	end)
end)
