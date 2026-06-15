require("spec.test_helper")

local test_helper = require("spec.test_helper")
local remove_stones = require("single_game.resolver.stages.remove_stones")
local content = require("content")
local board = require("board")
local config = require("config")

describe("remove_stones stage", function()
	it("removes kamikaze stone after commit", function()
		local state = test_helper.new_isolated_game("basic_stones")
		local stone_def = content.get_stone("kamikaze_stone")
		state.board[5][5] = board.make_stone(config.STONE_BLACK, "kamikaze_stone", 1, nil)
		local ctx = {
			state = state,
			actor = "black",
			row = 5,
			col = 5,
			stone_id = "kamikaze_stone",
			stone_def = stone_def,
			old_board = board.clone(state.board),
		}
		local _, kamikaze = remove_stones.run(ctx)
		assert.is_true(kamikaze)
		assert.is_true(board.is_empty(state.board[5][5]))
	end)
end)
