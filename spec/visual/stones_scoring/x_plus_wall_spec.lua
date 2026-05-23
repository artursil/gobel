local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local board = require("board")
local config = require("config")
local game = require("game")
local match_state = require("match_state")
local helper = require("spec.spec_helper")

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

test_helper.set_integration_debug_stone_letters(STONE_TO_LETTER)

local function new_base_state()
	local g = game.new("pvp", "basic_stones")
	g.run_state = { counters = {} }
	return g
end

local function set_hand(g, color, stone_ids)
	local player = match_state.player_for_color(g, color)
	player.stones.playable_stones = stone_ids
	player.stones.selected_stone = stone_ids[1]
	player.stones.selected_stone_index = 1
end

local function set_board(g, rows)
	g.board = helper.parse_board_ascii_kinds(rows, LETTER_TO_STONE)
end

local function place_stone(g, board_rows)
	local new_board = helper.parse_board_ascii_kinds(board_rows, LETTER_TO_STONE)
	for r = 1, config.BOARD_SIZE do
		for c = 1, config.BOARD_SIZE do
			if board.is_empty(g.board[r][c]) and not board.is_empty(new_board[r][c]) then
				local player = match_state.player_for_color(g, g.to_play)
				player.stones.selected_stone = new_board[r][c].kind
				test_helper.assert_legal_player_move(
					g,
					r,
					c,
					"place_stone must succeed at row " .. r .. " col " .. c
				)
				test_helper.finish_ui_animations_for_turn(g)
				return r, c
			end
		end
	end
	error("place_stone: no new stone found in board_rows compared to the current board")
end

describe("x_stone plus_stone wall scoring (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
	end)

	after_each(test_helper.visual_scoring_debug_after_each(function()
		return g
	end))

	describe("x_stone completes diagonal X and multiplies x_mult", function()
		it("minimal 5-cell X: place x_stone at center, black x_mult becomes 2", function()
			test_helper.assert_pattern_stones_in_content()
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
			local snap = test_helper.player_score_snapshot(g, "black")

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

			test_helper.assert_player_x_mult(g, "black", 2, "minimal 5-cell X applies one ×2 step")
			test_helper.assert_player_x_mult_delta(g, "black", snap, 1, "x_mult increases by 1 after ×2 from base 1")
		end)
	describe("any stone completes diagonal X and multiplies x_mult", function()
		it("minimal 5-cell X: place x_stone at center, black x_mult becomes 2", function()
			test_helper.assert_pattern_stones_in_content()
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
			local snap = test_helper.player_score_snapshot(g, "black")

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

			test_helper.assert_player_x_mult(g, "black", 2, "minimal 5-cell X applies one ×2 step")
			test_helper.assert_player_x_mult_delta(g, "black", snap, 1, "x_mult increases by 1 after ×2 from base 1")
		end)


		it("large 9-cell X: place x_stone at center, black x_mult becomes 4", function()
			test_helper.assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . B . . .",
				". . B . . B . . .",
				". . . . . . . . .",
				". . B . . B . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = test_helper.player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . B . B . . .",
				". . B . . B . . .",
				". . . . X . . . .",
				". . B . . B . . .",
				". . . B . B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_player_x_mult(g, "black", 4, "9-cell X applies two ×2 steps (cumulative ×4)")
			test_helper.assert_player_x_mult_delta(g, "black", snap, 3, "x_mult increases by 3 from 1 to 4")
		end)

		it("basic stone completes X while x_stone already on an arm: x_mult still becomes 2", function()
			test_helper.assert_pattern_stones_in_content()
			set_hand(g, "black", { "stone_basic" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . B . . X . . .",
				". . . . . . . . .",
				". . B . . B . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = test_helper.player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . B . . . .",
				". . B . . X . . .",
				". . . . B . . . .",
				". . B . . B . . .",
				". . . . B . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_player_x_mult(g, "black", 2, "X with x_stone on board triggers ×2 even if last stone is basic")
			test_helper.assert_player_x_mult_delta(g, "black", snap, 1, "x_mult increases by 1 when X completes")
		end)

		it("isolated x_stone placement does not change x_mult", function()
			test_helper.assert_pattern_stones_in_content()
			set_hand(g, "black", { "x_stone" })
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
			local snap = test_helper.player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . X . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_player_x_mult(g, "black", 1, "lonely x_stone does not form an X pattern")
			test_helper.assert_player_x_mult_unchanged(g, "black", snap, "x_mult unchanged without completed X")
		end)
	end)

	describe("plus_stone completes orthogonal plus and adds plus_mult", function()
		it("minimal 5-cell plus: place plus_stone at center, black plus_mult becomes 6", function()
			test_helper.assert_pattern_stones_in_content()
			set_hand(g, "black", { "plus_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . P P P . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = test_helper.player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . P P P . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_player_plus_mult(g, "black", 6, "minimal 5-cell plus adds one +5 tier")
			test_helper.assert_player_plus_mult_delta(g, "black", snap, 5, "plus_mult increases by 5")
		end)

		it("large 9-cell plus: place plus_stone at center, black plus_mult becomes 11", function()
			test_helper.assert_pattern_stones_in_content()
			set_hand(g, "black", { "plus_stone" })
			set_board(g, {
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . P . . . .",
				". . . P P P . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = test_helper.player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . P . . . .",
				". . . P P P . . .",
				". . . . P . . . .",
				". . . . P . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_player_plus_mult(g, "black", 11, "9-cell plus adds two +5 tiers")
			test_helper.assert_player_plus_mult_delta(g, "black", snap, 10, "plus_mult increases by 10 from 1 to 11")
		end)

		it("basic stone completes plus while plus_stone on arm: plus_mult still becomes 6", function()
			test_helper.assert_pattern_stones_in_content()
			set_hand(g, "black", { "stone_basic" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . P P P . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			local snap = test_helper.player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . P P P . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_player_plus_mult(
				g,
				"black",
				6,
				"plus with plus_stone on board triggers +5 even if last stone is basic"
			)
			test_helper.assert_player_plus_mult_delta(g, "black", snap, 5, "plus_mult increases by 5 when plus completes")
		end)

		it("isolated plus_stone placement does not change plus_mult", function()
			test_helper.assert_pattern_stones_in_content()
			set_hand(g, "black", { "plus_stone" })
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
			local snap = test_helper.player_score_snapshot(g, "black")

			place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . P . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_player_plus_mult(g, "black", 1, "lonely plus_stone does not form a plus pattern")
			test_helper.assert_player_plus_mult_unchanged(g, "black", snap, "plus_mult unchanged without completed plus")
		end)
	end)

	describe("wall stone groups add +2 points on board stones", function()
		it("basic stone placed beside two wall stones: only placed cell gets +2 modifier", function()
			test_helper.assert_pattern_stones_in_content()
			set_hand(g, "black", { "stone_basic" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			local row, col = place_stone(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W B . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_board_stone_points_bonus(
				g,
				row,
				col,
				2,
				"wall_stone_other grants +2 on placed non-wall only"
			)
			test_helper.assert_board_stone_modifier_absent(
				g,
				3,
				3,
				"existing wall at 3,3 must not gain wall_stone_other bonus"
			)
			test_helper.assert_board_stone_modifier_absent(
				g,
				3,
				4,
				"existing wall at 3,4 must not gain wall_stone_other bonus"
			)
		end)

		it("wall placed to extend a pair: all three connected wall cells get +2 modifier", function()
			test_helper.assert_pattern_stones_in_content()
			set_hand(g, "black", { "wall" })
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W . . . .",
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
				". . . W W W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})

			test_helper.assert_board_stone_points_bonus(g, 3, 3, 2, "wall_stone +2 on first wall of group")
			test_helper.assert_board_stone_points_bonus(g, 3, 4, 2, "wall_stone +2 on second wall of group")
			test_helper.assert_board_stone_points_bonus(g, 3, 5, 2, "wall_stone +2 on newly placed wall of group")
		end)
	end)
end)
