require("spec.test_helper")

local test_helper = require("spec.test_helper")
local board = require("board")
local config = require("config")
local tick_objects = require("single_game.resolver.stages.tick_objects")
local board_cell_timers = require("single_game.resolver.board_cell_timers")

describe("tick_objects stage", function()
	it("decrements cell-owned timer fields", function()
		local state = test_helper.new_isolated_game("basic_stones")
		local cell = board.make_stone(config.STONE_BLACK, "delay_reward_stone", 1, nil)
		cell.survival_rounds_remaining = 2
		cell.immunity_remaining = 3
		cell.timer_remaining_rounds = 2
		state.board[3][3] = cell
		tick_objects.decrement(state)
		assert.are.equal(1, state.board[3][3].survival_rounds_remaining)
		assert.are.equal(2, state.board[3][3].immunity_remaining)
		assert.are.equal(1, state.board[3][3].timer_remaining_rounds)
	end)

	it("decrements board_cell_timers when requested", function()
		local state = test_helper.new_isolated_game("basic_stones")
		board_cell_timers.register(state, 2, 2, 2)
		tick_objects.decrement(state, { decrement_board_cell_timers = true })
		assert.are.equal(1, state.board_cell_timers["2:2"])
	end)

	it("removes stones when board_cell_timers expire", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.board[6][6] = board.make_stone(config.STONE_WHITE, "self_destruct_stone", 1, nil)
		state.board_cell_timers = { ["6:6"] = 0 }
		tick_objects.remove_expired_timed_stones(state)
		assert.is_true(board.is_empty(state.board[6][6]))
		assert.is_nil(state.board_cell_timers["6:6"])
	end)
end)
