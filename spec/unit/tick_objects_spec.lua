require("spec.test_helper")

local test_helper = require("spec.test_helper")
local board = require("board")
local config = require("config")
local tick_objects = require("single_game.resolver.stages.tick_objects")
local duration_left = require("objects.effects_conditions.helpers.shared.duration_left")

describe("tick_objects stage", function()
	it("decrements duration_left on stone cells", function()
		local state = test_helper.new_isolated_game("basic_stones")
		local cell = board.make_stone(config.STONE_BLACK, "delay_reward_stone", 1, nil)
		cell.duration_left = 2
		state.board[3][3] = cell
		tick_objects.decrement(state)
		assert.are.equal(1, state.board[3][3].duration_left)
	end)

	it("migrates legacy survival_rounds_remaining into duration_left on decrement", function()
		local state = test_helper.new_isolated_game("basic_stones")
		local cell = board.make_stone(config.STONE_BLACK, "delay_reward_stone", 1, nil)
		cell.survival_rounds_remaining = 2
		state.board[3][3] = cell
		tick_objects.decrement(state)
		assert.are.equal(1, state.board[3][3].duration_left)
		assert.is_nil(state.board[3][3].survival_rounds_remaining)
	end)

	it("keeps duration_left at zero for tick expiry effects", function()
		local state = test_helper.new_isolated_game("basic_stones")
		local cell = board.make_stone(config.STONE_BLACK, "delay_reward_stone", 1, nil)
		cell.duration_left = 1
		state.board[3][3] = cell
		tick_objects.decrement(state)
		assert.are.equal(0, duration_left.remaining(state.board[3][3]))
	end)
end)
