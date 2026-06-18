require("spec.test_helper")

local test_helper = require("spec.test_helper")
local remove_stones = require("single_game.resolver.stages.remove_stones")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")
local board = require("board")
local config = require("config")

describe("remove_stones stage", function()
	it("drains enqueued kamikaze sacrifice", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.board[5][5] = board.make_stone(config.STONE_BLACK, "kamikaze_stone", 1, nil)
		pending_removals.enqueue_sacrifice(state, 5, 5, { capturer = "black" })
		local ctx = {
			state = state,
			actor = "black",
			player_chain_color = config.STONE_BLACK,
		}
		local _, kamikaze = remove_stones.run(ctx)
		assert.is_true(kamikaze)
		assert.is_true(board.is_empty(state.board[5][5]))
	end)
end)
