--- Visual spec: capture_stone (OBJECTS.md #19).
---
--- Stone under test: capture_stone
--- Captures one enemy stone with 0 liberties on placement, regardless of surrounding colors.
--- Opponent cannot recapture on the captured cell for 1 round when capture_stone removed
--- a stone in a mixed black/white surround (capture cooldown). No cooldown in captor-only surround.
--- If multiple targets at 0 liberties, one is selected at random.
--- During capture cooldown, opponent may still kamikaze on the blocked zero-liberty cell.
--- After cooldown, kamikaze has no sacrifice effect when the cell has liberties.
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")
local rules = require("rules")
local P = require("spec.parameters_helper")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	C = { color = config.STONE_BLACK, kind = "capture_stone" },
	c = { color = config.STONE_WHITE, kind = "capture_stone" },
	k = { color = config.STONE_WHITE, kind = "kamikaze_stone" },
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
local assert_board_cell_empty = test_helper.assert_board_cell_empty
local assert_legal_player_move_with_stone = test_helper.assert_legal_player_move_with_stone
local assert_illegal_player_move_with_stone = test_helper.assert_illegal_player_move_with_stone
local assert_cell_blocked = test_helper.assert_cell_blocked
local assert_cell_unblocked = test_helper.assert_cell_unblocked
local assert_territory_ascii = test_helper.assert_territory_ascii

local P = require("spec.parameters_helper")

--- @param capture_count integer
--- @return number
local function capture_bonus_for(capture_count)
	return P.capture_bonus_points(capture_count)
end

local S = P.stone

describe("capture_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "capture_stone", "kamikaze_stone" }, "capture_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("basic capture — zero liberties required", function()
		it("enemy stone fully surrounded has 0 liberties, capture_stone removes it and awards bonus", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
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
				". . . . B . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(1)
			assert_player_points_delta(g, "black", snap, expected_delta, "capture bonus awarded")
			assert_board_cell_empty(g, 5, 5, "captured white removed from board")
		end)

		it("enemy with 1 liberty remaining is NOT captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W . . . .",
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
				". . . . B . . . .",
				". . . B W . . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_board_stone_present(g, 5, 5, "white stone still has 1 liberty, not captured")
			assert_player_points_unchanged(g, "black", snap, "no bonus when target has remaining liberties")
		end)

		it("no enemy on board means no capture and no bonus", function()
			set_hand(g, "black", { "capture_stone" })
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

			assert_player_points_unchanged(g, "black", snap, "empty board no capture no bonus")
		end)

		it("enemy surrounded by mix of black and white stones still captured at 0 liberties", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
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
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(1)
			assert_player_points_delta(g, "black", snap, expected_delta, "mixed surround still captures at 0 liberties")
			assert_board_cell_empty(g, 5, 5, "white removed despite mixed surrounding colors")
		end)

	end)

	describe("corner and edge captures", function()
		it("corner stone at (1,1) with 0 liberties is captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				"W W . . . . . . .",
				". . . . . . . . .",
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
				"W W . . . . . . .",
				"C . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(1)
			assert_player_points_delta(g, "black", snap, expected_delta, "corner capture bonus")
			assert_board_cell_empty(g, 1, 1, "corner white captured")
		end)

		it("edge stone at (1,5) with 0 liberties is captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . W W B . . .",
				". . . . . . . . .",
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
				". . . W W B . . .",
				". . . . C . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(1)
			assert_player_points_delta(g, "black", snap, expected_delta, "edge capture bonus")
			assert_board_cell_empty(g, 1, 5, "edge white captured")
		end)

		it("bottom-right corner stone at (9,9) with 0 liberties is captured", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . W W",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . C",
				". . . . . . . W W",
			})

			local expected_delta = capture_bonus_for(1)
			assert_player_points_delta(g, "black", snap, expected_delta, "bottom-right corner capture bonus")
			assert_board_cell_empty(g, 9, 9, "bottom-right corner white captured")
		end)
	end)

	describe("capture cooldown — opponent cannot recapture immediately", function()
		it("opponent cannot place on captured cell for 1 round", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_board_cell_empty(g, 5, 5, "white captured and removed")
			assert_cell_blocked(g, 5, 5, "captured cell blocked for opponent")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "opponent cannot immediately recapture")
		end)

		it("capturing player CAN place on captured cell immediately", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_board_cell_empty(g, 5, 5, "white captured")
			set_hand(g, "black", { "stone_basic" })
			assert_legal_player_move_with_stone(g, "black", "stone_basic", 5, 5, "captor can place on captured cell immediately")
		end)

		it("cooldown expires after 1 round, opponent can then place on captured cell", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_cell_blocked(g, 5, 5, "still blocked immediately after capture")
			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "cooldown expired after 1 round")
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "opponent places on captured cell after cooldown")
		end)

		it("during cooldown opponent kamikaze on blocked zero-liberty cell pays bonus", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_board_cell_empty(g, 5, 5, "white captured before kamikaze")
			assert_cell_blocked(g, 5, 5, "captured cell blocked for stone_basic")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "stone_basic still blocked during cooldown")

			local snap = player_score_snapshot(g, "white")
			test_helper.place_stone_for(g, "white", "kamikaze_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B k C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "white", snap, S.kamikaze_points_bonus, "kamikaze bonus during cooldown on zero-liberty cell")
			assert_board_cell_empty(g, 5, 5, "kamikaze self-removes after payout")
		end)

		it("after cooldown pays kamikaze_points_bonus and self-removes on a cell with liberties", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_cell_blocked(g, 5, 5, "captured cell on cooldown")
			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "cooldown expired")
			local legal_after_cooldown = rules.try_play(g.board, 5, 5, config.STONE_WHITE, g.ko_ban, "stone_basic")
			assert.is_true(legal_after_cooldown, "cell has liberties after cooldown")

			local snap = player_score_snapshot(g, "white")
			test_helper.place_stone_for(g, "white", "kamikaze_stone", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B k C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_points_delta(g, "white", snap, S.kamikaze_points_bonus, "kamikaze pays configured bonus after cooldown even when cell has liberties")
			assert_board_cell_empty(g, 5, 5, "kamikaze self-removes after payout")
		end)
	end)

	describe("multi-round recapture scenario", function()
		it("mixed surround: opponent places on captured cell after cooldown expires", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_board_cell_empty(g, 5, 5, "white captured round 1")
			assert_cell_blocked(g, 5, 5, "mixed-surround capture triggers cooldown")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "blocked during cooldown")

			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "cooldown expired")
			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_board_stone_present(g, 5, 5, "white recaptured the cell after cooldown")
		end)

		it("captor-only surround: no cooldown and sealed pocket stays illegal for opponent", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_board_cell_empty(g, 5, 5, "white captured in black-only surround")
			assert_cell_unblocked(g, 5, 5, "no cooldown when only captor stones surround")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "sealed pocket illegal even without cooldown")

			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "still no cooldown after advance")
			assert_illegal_player_move_with_stone(g, "white", "stone_basic", 5, 5, "sealed pocket still illegal after advance")
		end)

		it("two mixed-surround captures on different cells get independent cooldowns", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . W .",
				". . . B W . B W .",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . W .",
				". . . B . C B W .",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_board_cell_empty(g, 5, 5, "left pocket white captured at (5,5)")
			assert_cell_blocked(g, 5, 5, "left capture cell on cooldown")
			assert_cell_unblocked(g, 5, 8, "right pocket not on cooldown yet")
			test_helper.assert_board_stone_present(g, 5, 8, "right pocket white still on board")

			test_helper.pass_turn(g)
			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 5, "left capture cooldown expired before second capture")

			set_hand(g, "black", { "capture_stone" })
			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . W .",
				". . . B . C B . C",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_board_cell_empty(g, 5, 8, "right pocket white captured at (5,8)")
			assert_cell_unblocked(g, 5, 5, "left pocket free after second capture")
			assert_cell_blocked(g, 5, 8, "right capture cell on cooldown")

			test_helper.advance_rounds(g, 1)
			assert_cell_unblocked(g, 5, 8, "right capture cooldown expired")

			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . W .",
				". . . B W C B . C",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_board_stone_present(g, 5, 5, "white reclaimed left pocket after cooldown")

			test_helper.pass_turn(g)
			test_helper.place_stone_for(g, "white", "stone_basic", {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W . . W .",
				". . . B W C B W C",
				". . . . B . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.assert_board_stone_present(g, 5, 8, "white reclaimed right pocket after cooldown")
		end)
	end)

	describe("multiple targets — random selection", function()
		it("shared last liberty creates two targets, RNG picks first: only one captured", function()
			test_helper.set_rng_stream(g, "capture_stone", test_helper.rng_always_one)
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . B . B . . .",
				". . B W . W B . .",
				". . B W . W B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . B . B . . .",
				". . B W C W B . .",
				". . B W . W B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(1)
			assert_player_points_delta(g, "black", snap, expected_delta, "only one capture bonus even with two targets")
			assert_board_cell_empty(g, 3, 4, "left white captured first by RNG")
			test_helper.assert_board_stone_present(g, 3, 6, "right white still on board at 0 liberties")
		end)

		it("shared liberty: right white regular capture, left white capture_stone capture", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . B . B . . .",
				". . B W . W B . .",
				". . B W . B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . B . B . . .",
				". . B W C W B . .",
				". . B W . B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(2)
			assert_player_points_delta(g, "black", snap, expected_delta, "global capture bonus for two stones removed")
			assert_board_cell_empty(g, 3, 6, "right white removed by regular capture")
			assert_board_cell_empty(g, 3, 4, "top-left white removed by capture_stone")
			test_helper.assert_board_stone_present(g, 4, 4, "lower-left white survives with remaining liberties")
		end)
	end)

	describe("multi-stone group captures", function()
		it("horizontal two-stone chain with one liberty: regular capture removes one pocketed stone", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B W W B . .",
				". . . B . B B . .",
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
				". . . B W W B . .",
				". . . B C B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(2)
			assert_player_points_delta(g, "black", snap, expected_delta, "global capture bonus for two removed stones")
			assert_board_cell_empty(g, 5, 5, "left chain stone removed by regular capture")
			assert_board_cell_empty(g, 5, 6, "right chain stone removed by regular capture")
		end)

		it("L-shaped three-stone group with one liberty: regular capture removes entire group", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B W W B . .",
				". . . B W B B . .",
				". . . B . B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B W W B . .",
				". . . B W B B . .",
				". . . B C B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(3)
			assert_player_points_delta(g, "black", snap, expected_delta, "global capture bonus for three-stone group")
			assert_board_cell_empty(g, 5, 5, "corner stone of L removed")
			assert_board_cell_empty(g, 5, 6, "arm stone of L removed")
			assert_board_cell_empty(g, 6, 5, "stem stone of L removed")
		end)

		it("mixed-surround two-stone chain: capture_stone removes exactly one stone", function()
			test_helper.set_rng_stream(g, "capture_stone", test_helper.rng_always_one)
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W W . . .",
				". . . B W W . . .",
				". . . . B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W W . . .",
				". . . B W W C . .",
				". . . . B B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(1)
			assert_player_points_delta(g, "black", snap, expected_delta, "global capture bonus for one removed stone")
			assert_board_cell_empty(g, 5, 5, "left chain stone removed by capture")
			test_helper.assert_board_stone_present(g, 5, 6, "right chain stone survives with remaining liberties")
		end)

		it("mixed-surround three-stone chain: RNG picks one stone from group at 0 liberties", function()
			test_helper.set_rng_stream(g, "capture_stone", test_helper.rng_always_one)
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W W W . .",
				". . . B W W W . .",
				". . . . B B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . W W W . .",
				". . . B W W W C .",
				". . . . B B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local expected_delta = capture_bonus_for(1)
			assert_player_points_delta(g, "black", snap, expected_delta, "global capture bonus for one removed stone")
			assert_board_cell_empty(g, 5, 5, "left chain stone removed by capture")
			test_helper.assert_board_stone_present(g, 5, 6, "middle chain stone survives with remaining liberties")
			test_helper.assert_board_stone_present(g, 5, 7, "right chain stone survives with remaining liberties")
		end)

		it("regular capture of chain updates territory inside black pocket", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B W W B . .",
				". . . B . B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B B B . . .",
				". . . B W W B . .",
				". . . B C B B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_board_cell_empty(g, 5, 5, "chain cleared from pocket")
			assert_board_cell_empty(g, 5, 6, "chain cleared from pocket")
			assert_territory_ascii(g, {
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b B B B b b b",
				"b b b B b b B b b",
				"b b b B B B B b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
				"b b b b b b b b b",
			}, "pocket interior becomes black territory after chain removed")
		end)
	end)


	describe("prisoners tracking", function()
		it("successful capture increments prisoner count", function()
			set_hand(g, "black", { "capture_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W . . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local prisoners_before = g.players.black.prisoners or 0

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . . B W C . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert.is_true(
				(g.players.black.prisoners or 0) >= prisoners_before + 1,
				"prisoner counter incremented after capture"
			)
		end)
	end)

end)
