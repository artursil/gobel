--- Visual spec: anti_capture_stone (OBJECTS.md #16).
---
--- Stone under test: anti_capture_stone
--- Prevents opponent from placing on a cell when that placement would capture the
--- immune stone or its connected own group. Immunity lasts S.anti_capture_duration_rounds
--- from placement snapshot (placed stone + orthogonally connected own stones at trigger).
---
local test_helper = require("spec.test_helper")
test_helper.install_love_test_stubs()

local board = require("board")
local config = require("config")
local match_state = require("match_state")
local resolver = require("resolver")
local P = require("spec.parameters_helper")
local anti_capture = require("single_game.resolver.stages_helpers.anti_capture")

local LETTER_TO_STONE = {
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
	W = { color = config.STONE_WHITE, kind = "stone_basic" },
	A = { color = config.STONE_BLACK, kind = "anti_capture_stone" },
	a = { color = config.STONE_WHITE, kind = "anti_capture_stone" },
}

local STONE_TO_LETTER = {}
for letter, def in pairs(LETTER_TO_STONE) do
	STONE_TO_LETTER[def.kind] = letter
end

test_helper.set_visual_board_letters(LETTER_TO_STONE, STONE_TO_LETTER)

local new_base_state = test_helper.new_isolated_game
local set_board = test_helper.set_board
local visual_scoring_debug_after_each = test_helper.visual_scoring_debug_after_each
local assert_stone_ids_registered_in_content = test_helper.assert_stone_ids_registered_in_content
local assert_legal_player_move_with_stone = test_helper.assert_legal_player_move_with_stone
local S = P.stone

local function stone_immunity_remaining(g, row, col)
	return anti_capture.remaining(g, row, col)
end

local function assert_stone_immune(g, row, col, expected, context)
	assert.are.equal(expected, stone_immunity_remaining(g, row, col), context)
end

local function assert_stone_not_immune(g, row, col, context)
	assert.are.equal(0, stone_immunity_remaining(g, row, col), context)
end

local function try_player_move_at_board_snapshot(g, side, stone_id, row, col)
	test_helper.set_hand(g, side, { stone_id })
	g.to_play = side
	g.phase = "PLACE_PHASE"
	local player = match_state.player_for_color(g, side)
	player.stones.selected_stone = stone_id
	player.stones.selected_stone_index = 1
	local result = resolver.submit_action(g, {
		actor = side,
		type = "PLACE_STONE",
		payload = { row = row, col = col },
	})
	test_helper.finish_ui_animations_for_turn(g)
	return result.ok
end

local function assert_illegal_player_move_at_snapshot(g, side, stone_id, row, col, context)
	local before = board.clone(g.board)
	local points_before = match_state.player_for_color(g, side).score.points
	local ok = try_player_move_at_board_snapshot(g, side, stone_id, row, col)
	assert.is_false(ok, context)
	local after = g.board
	for r = 1, config.BOARD_SIZE do
		for c = 1, config.BOARD_SIZE do
			local b_cell = before[r][c]
			local a_cell = after[r][c]
			local b_empty = board.is_empty(b_cell)
			local a_empty = board.is_empty(a_cell)
			if b_empty ~= a_empty then
				error((context or "illegal move") .. ": board mutated on rejected placement")
			end
			if not b_empty and not a_empty and (b_cell.kind ~= a_cell.kind or b_cell.color ~= a_cell.color) then
				error((context or "illegal move") .. ": board mutated on rejected placement")
			end
		end
	end
	assert.are.equal(points_before, match_state.player_for_color(g, side).score.points, context)
end

describe("anti_capture_stone (visual ASCII)", function()
	local g

	before_each(function()
		g = new_base_state()
		assert_stone_ids_registered_in_content({ "anti_capture_stone" }, "anti_capture_stone")
	end)

	after_each(visual_scoring_debug_after_each(function()
		return g
	end))

	describe("capture denial at last liberty", function()
		it("solo A threatened: white cannot play the capturing stone", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W A W . . .",
				". . . W . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_stone_immune(g, 4, 5, S.anti_capture_duration_rounds, "A immune from placement")
			assert_illegal_player_move_at_snapshot(g, "white", "stone_basic", 5, 5,
				"white cannot fill last liberty while A is immune")
			test_helper.assert_board_stone_present(g, 4, 5, "A survives rejected capture attempt")
		end)

		it("same surround with basic B: white capture at last liberty is legal", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_stone_not_immune(g, 4, 5, "basic B has no immunity")
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 5, 5,
				"without immunity white captures at last liberty")
			test_helper.assert_board_cell_empty(g, 4, 5, "unprotected B removed")
		end)
	end)

	describe("connected group immunity", function()
		it("B+A chain shares one liberty: white capture attempt rejected", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W A W . . .",
				". . . W . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_stone_immune(g, 5, 5, S.anti_capture_duration_rounds, "A in chain immune")
			assert_stone_immune(g, 4, 5, S.anti_capture_duration_rounds, "connected B immune")
			assert_illegal_player_move_at_snapshot(g, "white", "stone_basic", 6, 5,
				"white cannot capture connected B+A group")
			test_helper.assert_board_stone_present(g, 4, 5, "B survives")
			test_helper.assert_board_stone_present(g, 5, 5, "A survives")
		end)

		it("ring of B around A: white cannot capture entire group at last liberty", function()
			set_board(g, {
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W A W . . .",
				". . . W B W . . .",
				". . . W . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			assert_stone_immune(g, 4, 5, S.anti_capture_duration_rounds, "center A immune")
			assert_stone_immune(g, 3, 5, S.anti_capture_duration_rounds, "top B immune")
			assert_stone_immune(g, 5, 5, S.anti_capture_duration_rounds, "bottom B immune")
			assert_illegal_player_move_at_snapshot(g, "white", "stone_basic", 6, 5,
				"white cannot capture entire ring at last liberty")
			test_helper.assert_board_stone_present(g, 3, 5, "top B survives")
			test_helper.assert_board_stone_present(g, 4, 5, "center A survives")
			test_helper.assert_board_stone_present(g, 5, 5, "bottom B survives")
		end)

		it("connected B+A group capturable after full duration", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W B W . . .",
				". . . W A W . . .",
				". . . W . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.anti_capture_duration_rounds)
			assert_stone_not_immune(g, 5, 5, "immunity expired")
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 6, 5,
				"entire B+A group capturable after expiry")
			test_helper.assert_board_cell_empty(g, 4, 5, "B removed")
			test_helper.assert_board_cell_empty(g, 5, 5, "A removed")
		end)

		it("solo A capturable after full duration", function()
			set_board(g, {
				". . . . . . . . .",
				". . . . . . . . .",
				". . . W W W . . .",
				". . . W A W . . .",
				". . . W . W . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
				". . . . . . . . .",
			})
			test_helper.advance_rounds(g, S.anti_capture_duration_rounds)
			assert_stone_not_immune(g, 4, 5, "solo A immunity expired")
			assert_legal_player_move_with_stone(g, "white", "stone_basic", 5, 5,
				"white captures solo A after expiry")
			test_helper.assert_board_cell_empty(g, 4, 5, "A removed")
		end)
	end)
end)
