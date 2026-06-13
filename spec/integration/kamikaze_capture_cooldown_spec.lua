require("spec.test_helper")

local config = require("config")
local rules = require("rules")
local test_helper = require("spec.test_helper")
local P = require("spec.parameters_helper")

describe("kamikaze_stone after capture_stone cooldown", function()
	local LETTER_TO_STONE = {
		B = { color = config.STONE_BLACK, kind = "stone_basic" },
		W = { color = config.STONE_WHITE, kind = "stone_basic" },
		C = { color = config.STONE_BLACK, kind = "capture_stone" },
		k = { color = config.STONE_WHITE, kind = "kamikaze_stone" },
	}

	local STONE_TO_LETTER = {}
	for letter, def in pairs(LETTER_TO_STONE) do
		STONE_TO_LETTER[def.kind] = letter
	end

	test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

	local g

	before_each(function()
		g = test_helper.new_isolated_game()
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
	end)

	it("after cooldown pays kamikaze_points_bonus and self-removes on a cell with liberties", function()
		test_helper.set_hand(g, "black", { "capture_stone" })
		test_helper.set_board(g, {
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

		test_helper.place_stone(g, {
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

		test_helper.assert_board_cell_empty(g, 5, 5, "capture removes enemy stone")
		test_helper.assert_cell_blocked(g, 5, 5, "mixed-surround capture blocks recapture cell")
		test_helper.advance_rounds(g, 1)
		test_helper.assert_cell_unblocked(g, 5, 5, "cooldown expired after one round")

		local legal_after_cooldown = rules.try_play(g.board, 5, 5, config.STONE_WHITE, g.ko_ban, "stone_basic")
		assert.is_true(legal_after_cooldown, "captured cell has liberties after cooldown")

		local snap = test_helper.player_score_snapshot(g, "white")
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

		test_helper.assert_player_points_delta(
			g,
			"white",
			snap,
			P.kamikaze_points_bonus(),
			"kamikaze pays configured bonus after cooldown even when cell has liberties"
		)
		test_helper.assert_board_cell_empty(g, 5, 5, "kamikaze self-removes after payout")
	end)
end)
