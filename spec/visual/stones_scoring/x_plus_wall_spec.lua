local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local config = require("config")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	X = { color = config.STONE_BLACK, kind = "x_stone" },
	P = { color = config.STONE_BLACK, kind = "plus_stone" },
	W = { color = config.STONE_BLACK, kind = "wall" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_hand = test_helper.set_hand
local set_energy = test_helper.set_energy
local set_money = test_helper.set_money
local set_cards = test_helper.set_cards
local set_stances = test_helper.set_stances
local set_round = test_helper.set_round
local set_persistent_counter = test_helper.set_persistent_counter
local set_points = test_helper.set_points
local set_mult = test_helper.set_mult
local set_x_mult = test_helper.set_x_mult
local set_board = test_helper.set_board
local play_card = test_helper.play_card
local play_cards = test_helper.play_cards
local place_stone = test_helper.place_stone
local play_card_and_stone = test_helper.play_card_and_stone
local player_score_snapshot = test_helper.player_score_snapshot
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_pattern_stones_in_content = test_helper.assert_pattern_stones_in_content
local assert_player_x_mult = test_helper.assert_player_x_mult
local assert_player_x_mult_delta = test_helper.assert_player_x_mult_delta
local assert_player_x_mult_unchanged = test_helper.assert_player_x_mult_unchanged
local assert_player_plus_mult = test_helper.assert_player_plus_mult
local assert_player_plus_mult_delta = test_helper.assert_player_plus_mult_delta
local assert_player_plus_mult_unchanged = test_helper.assert_player_plus_mult_unchanged
local assert_board_stone_points_bonus = test_helper.assert_board_stone_points_bonus
local assert_board_stone_modifier_absent = test_helper.assert_board_stone_modifier_absent

describe("x_stone plus_stone wall scoring (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))
	describe("x_stone completes diagonal X and multiplies x_mult", function()
		it("minimal 5-cell X: place x_stone at center, black x_mult becomes 2", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . B . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . X . B . . .",
				". . . . B . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 2, "minimal 5-cell X applies one ×2 step")
			assert_player_x_mult_delta(g, "black", snap, 1, "x_mult increases by 1 after ×2 from base 1")
		end)
		it("minimal 5-cell X: completing the X with 3 x_stones, black x_mult becomes 8", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . X . . . .",
				". . . X . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . X . B . . .",
				". . . . X . . . .",
				". . . X . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 8, "minimal 5-cell X completes with 3 x_stones, black x_mult becomes 8")
			assert_player_x_mult_delta(g, "black", snap, 7, "x_mult increases by 7 from 1 to 8")
		end)
	end)
	describe("any stone completes diagonal X and multiplies x_mult", function()
		it("minimal 5-cell X: place x_stone at center, black x_mult becomes 2", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 2, "minimal 5-cell X applies one ×2 step")
			assert_player_x_mult_delta(g, "black", snap, 1, "x_mult increases by 1 after ×2 from base 1")
		end)


		it("large 9-cell X: place x_stone, black x_mult becomes 4", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 2)
			set_board(g, {
				". . . . . . . . .",
				". . B . . . . . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . B . . . B . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 4, "9-cell X applies two ×2 steps (cumulative ×4)")
			assert_player_x_mult_delta(g, "black", snap, 2, "x_mult increases by 2 from 2 to 4")
		end)
		it("large 9-cell X: complete large X with x_stone, black x_mult becomes 4", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 2)
			set_board(g, {
				". . . . . . . . .",
				". . B . . . . . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 8, "9-cell X applies two ×2 steps twice (cumulative ×8)")
			assert_player_x_mult_delta(g, "black", snap, 6, "x_mult increases by 6 from 6 to 8")
		end)
		it("large 9-cell X: adding a stone not completing the X does not change x_mult", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 6)
			set_board(g, {
				". . . . . . . . .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . B .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 6, "adding a stone not completing the X does not change x_mult")
			assert_player_x_mult_delta(g, "black", snap, 0, "x_mult unchanged without completed X")
		end)
		it("large 9-cell X: adding a stone completing 2 Xs, 3 times x2 is triggered", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 2)
			set_board(g, {
				". . . . . . . . .",
				". . . . B . X . .",
				". . . B . B . . .",
				". . B . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . B . B . X . .",
				". . . B . B . . .",
				". . B . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_x_mult(g, "black", 16, "adding a stone completing 2 Xs, 3 times x2 is triggered")
			assert_player_x_mult_delta(g, "black", snap, 14, "x_mult increases by 14 from 2 to 16")
		end)
		it("large 9-cell X: adding an x_stone completing 2 Xs, 5 times x2 is triggered", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 2)
			set_board(g, {
				". . . . . . . . .",
				". . . . B . X . .",
				". . . B . B . . .",
				". . B . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . X . B . X . .",
				". . . B . B . . .",
				". . B . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_player_x_mult(g, "black", 64, "adding a stone completing 2 Xs, 5 times x2 is triggered")
			assert_player_x_mult_delta(g, "black", snap, 62, "x_mult increases by 62 from 2 to 64")
		end)
		it("large 13-cell X: completing large X with 3 x_stones, black x_mult becomes 48", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 6)
			set_board(g, {
				". B . . . . . . .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". B . . . . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				". B . . . . . X .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". B . . . . . B .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			assert_player_x_mult(g, "black", 48, "large 13-cell X completed with 3 x_stones, black x_mult becomes 48")
			assert_player_x_mult_delta(g, "black", snap, 42, "x_mult increases by 42 from 6 to 48")
		end)
		it("large 17-cell X: completing large X with 3 x_stones, black x_mult becomes 384", function()
			assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_x_mult(g, "black", 48)
			set_board(g, {
				". . . . . . . . B",
				". B . . . . . X .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". B . . . . . B .",
				"B . . . . . . . B",
			})
			local snap = player_score_snapshot(g, "black")

			place_stone(g, {
				"B . . . . . . . B",
				". B . . . . . X .",
				". . B . . . X . .",
				". . . B . B . . .",
				". . . . X . . . .",
				". . . B . B . . .",
				". . B . . . B . .",
				". B . . . . . B .",
				"B . . . . . . . B",
			})

			assert_player_x_mult(g, "black", 384, "large 17-cell X completed with 3 x_stones, black x_mult becomes 384")
			assert_player_x_mult_delta(g, "black", snap, 336, "x_mult increases by 336 from 48 to 384")
		end)
	end)

	-- 	it("basic stone completes X while x_stone already on an arm: x_mult still becomes 2", function()
	-- 		assert_pattern_stones_in_content()
	-- 		set_hand(g, "black", { "stone_basic" })
	-- 		set_board(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . B . . . .",
	-- 			". . B . . X . . .",
	-- 			". . . . . . . . .",
	-- 			". . B . . B . . .",
	-- 			". . . . B . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})
	-- 		local snap = player_score_snapshot(g, "black")

	-- 		place_stone(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . B . . . .",
	-- 			". . B . . X . . .",
	-- 			". . . . B . . . .",
	-- 			". . B . . B . . .",
	-- 			". . . . B . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		assert_player_x_mult(g, "black", 2, "X with x_stone on board triggers ×2 even if last stone is basic")
	-- 		assert_player_x_mult_delta(g, "black", snap, 1, "x_mult increases by 1 when X completes")
	-- 	end)

	-- 	it("isolated x_stone placement does not change x_mult", function()
	-- 		assert_pattern_stones_in_content()
	-- 		set_hand(g, "black", { "x_stone" })
	-- 		set_board(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})
	-- 		local snap = player_score_snapshot(g, "black")

	-- 		place_stone(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . X . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		assert_player_x_mult(g, "black", 1, "lonely x_stone does not form an X pattern")
	-- 		assert_player_x_mult_unchanged(g, "black", snap, "x_mult unchanged without completed X")
	-- 	end)
	-- end)

	-- describe("plus_stone completes orthogonal plus and adds plus_mult", function()
	-- 	it("minimal 5-cell plus: place plus_stone at center, black plus_mult becomes 6", function()
	-- 		assert_pattern_stones_in_content()
	-- 		set_hand(g, "black", { "plus_stone" })
	-- 		set_board(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . P P P . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})
	-- 		local snap = player_score_snapshot(g, "black")

	-- 		place_stone(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . P P P . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		assert_player_plus_mult(g, "black", 6, "minimal 5-cell plus adds one +5 tier")
	-- 		assert_player_plus_mult_delta(g, "black", snap, 5, "plus_mult increases by 5")
	-- 	end)

	-- 	it("large 9-cell plus: place plus_stone at center, black plus_mult becomes 11", function()
	-- 		assert_pattern_stones_in_content()
	-- 		set_hand(g, "black", { "plus_stone" })
	-- 		set_board(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . P P P . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})
	-- 		local snap = player_score_snapshot(g, "black")

	-- 		place_stone(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . P P P . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		assert_player_plus_mult(g, "black", 11, "9-cell plus adds two +5 tiers")
	-- 		assert_player_plus_mult_delta(g, "black", snap, 10, "plus_mult increases by 10 from 1 to 11")
	-- 	end)

	-- 	it("basic stone completes plus while plus_stone on arm: plus_mult still becomes 6", function()
	-- 		assert_pattern_stones_in_content()
	-- 		set_hand(g, "black", { "stone_basic" })
	-- 		set_board(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . P P P . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})
	-- 		local snap = player_score_snapshot(g, "black")

	-- 		place_stone(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . P P P . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		assert_player_plus_mult(
	-- 			g,
	-- 			"black",
	-- 			6,
	-- 			"plus with plus_stone on board triggers +5 even if last stone is basic"
	-- 		)
	-- 		assert_player_plus_mult_delta(g, "black", snap, 5, "plus_mult increases by 5 when plus completes")
	-- 	end)

	-- 	it("isolated plus_stone placement does not change plus_mult", function()
	-- 		assert_pattern_stones_in_content()
	-- 		set_hand(g, "black", { "plus_stone" })
	-- 		set_board(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})
	-- 		local snap = player_score_snapshot(g, "black")

	-- 		place_stone(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . P . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		assert_player_plus_mult(g, "black", 1, "lonely plus_stone does not form a plus pattern")
	-- 		assert_player_plus_mult_unchanged(g, "black", snap, "plus_mult unchanged without completed plus")
	-- 	end)
	-- end)

	-- describe("wall stone groups add +2 points on board stones", function()
	-- 	it("basic stone placed beside two wall stones: only placed cell gets +2 modifier", function()
	-- 		assert_pattern_stones_in_content()
	-- 		set_hand(g, "black", { "stone_basic" })
	-- 		set_board(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . W W . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		local row, col = place_stone(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . W W B . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		assert_board_stone_points_bonus(
	-- 			g,
	-- 			row,
	-- 			col,
	-- 			2,
	-- 			"wall_stone_other grants +2 on placed non-wall only"
	-- 		)
	-- 		assert_board_stone_modifier_absent(
	-- 			g,
	-- 			3,
	-- 			3,
	-- 			"existing wall at 3,3 must not gain wall_stone_other bonus"
	-- 		)
	-- 		assert_board_stone_modifier_absent(
	-- 			g,
	-- 			3,
	-- 			4,
	-- 			"existing wall at 3,4 must not gain wall_stone_other bonus"
	-- 		)
	-- 	end)

	-- 	it("wall placed to extend a pair: all three connected wall cells get +2 modifier", function()
	-- 		assert_pattern_stones_in_content()
	-- 		set_hand(g, "black", { "wall" })
	-- 		set_board(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . W W . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		place_stone(g, {
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . W W W . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 			". . . . . . . . .",
	-- 		})

	-- 		assert_board_stone_points_bonus(g, 3, 3, 2, "wall_stone +2 on first wall of group")
	-- 		assert_board_stone_points_bonus(g, 3, 4, 2, "wall_stone +2 on second wall of group")
	-- 		assert_board_stone_points_bonus(g, 3, 5, 2, "wall_stone +2 on newly placed wall of group")
	-- 	end)
	-- end)
end)
