require("spec.test_helper")

local test_helper = require("spec.test_helper")
local board = require("board")
local config = require("config")
local dispatch_removed = require("single_game.resolver.stages.dispatch_removed")
local match_state = require("match_state")

describe("dispatch_removed stage", function()
	it("dispatches on_removed when a stone leaves the board", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.scores = { points = { B = 1, W = 1 } }
		state.board[4][4] = board.make_stone(config.STONE_BLACK, "escalating_points_stone", 1, nil)
		state.board[4][4].stored_value = 10
		local old_board = board.clone(state.board)
		old_board[4][4].stored_value = 10
		state.board[4][4] = config.STONE_NONE
		dispatch_removed.run(state, old_board, state.board, { capturer = "white" })
		local white = match_state.player_for_color(state, "white")
		assert.is_true(white.score.points > 1)
	end)

	it("skips on_removed for kamikaze sacrifice cells", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.scores = { points = { B = 1, W = 1 } }
		state.board[5][5] = board.make_stone(config.STONE_BLACK, "escalating_points_stone", 1, nil)
		state.board[5][5].stored_value = 10
		local old_board = board.clone(state.board)
		old_board[5][5].stored_value = 10
		state.board[5][5] = config.STONE_NONE
		dispatch_removed.run(state, old_board, state.board, {
			capturer = "white",
			skip_sacrifice_cell = { row = 5, col = 5 },
		})
		local white = match_state.player_for_color(state, "white")
		assert.are.equal(1, white.score.points)
	end)
end)
