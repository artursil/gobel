require("spec.test_helper")

local test_helper = require("spec.test_helper")
local board = require("board")
local config = require("config")
local resolve_round = require("single_game.resolver.resolve_round")
local remove_stones = require("single_game.resolver.stages.remove_stones")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")
local stone_params = require("objects.parameters.stones")
local effect_manager = require("single_game.resolver.effect_manager")

describe("timed stones tick action", function()
	it("collects tick effects only for cells with duration_left", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.board[4][4] = board.make_stone(config.STONE_BLACK, "points_stone", 1, nil)
		state.board[5][5] = board.make_stone(config.STONE_BLACK, "delay_reward_stone", 1, nil)
		state.board[5][5].duration_left = 1
		state._resolve_action = "tick"
		local effects = effect_manager.collect_effects(state, "tick", "points", nil)
		local tick_names = {}
		for i = 1, #effects do
			if effects[i].effect_name == "delay_reward_payout" then
				tick_names[#tick_names + 1] = effects[i].effect_name
			end
		end
		assert.are.equal(1, #tick_names)
	end)

	it("delay_reward pays only after duration_left reaches zero at end_of_turn", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.board[5][5] = board.make_stone(config.STONE_BLACK, "delay_reward_stone", 1, nil)
		state.board[5][5].duration_left = stone_params.points_delay_rounds
		state.board[5][5].delay_payout = stone_params.points_delay_payout
		local points_before = state.scores.points.B
		for _ = 1, stone_params.points_delay_rounds do
			resolve_round.resolve(state, { action = "end_of_turn" })
		end
		assert.are.equal(points_before + stone_params.points_delay_payout, state.scores.points.B)
	end)

	it("self_destruct_expire enqueues removal and drain clears the cell after tick beat", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.board[5][5] = board.make_stone(config.STONE_BLACK, "self_destruct_timed_stone", 1, nil)
		state.board[5][5].duration_left = 1
		resolve_round.resolve(state, { action = "end_of_turn" })
		assert.is_true(board.is_empty(state.board[5][5]))
		assert.are.equal(0, pending_removals.pending_count(state))
	end)

	it("anti_capture_expire does not enqueue pending removals", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.board[5][5] = board.make_stone(config.STONE_BLACK, "anti_capture_stone", 1, nil)
		state.board[5][5].duration_left = 1
		resolve_round.resolve(state, { action = "end_of_turn" })
		assert.is_false(board.is_empty(state.board[5][5]))
		assert.are.equal(0, pending_removals.pending_count(state))
	end)
end)
