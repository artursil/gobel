require("spec.test_helper")

local board = require("board")
local config = require("config")
local content = require("content")
local match_state = require("match_state")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")
local remove_stones = require("single_game.resolver.stages.remove_stones")
local resolve_round = require("single_game.resolver.resolve_round")
local test_helper = require("spec.test_helper")

describe("pending_stone_removals", function()
	it("enqueue and take_all preserve entry order", function()
		local state = test_helper.new_isolated_game("basic_stones")
		pending_removals.enqueue(state, { row = 1, col = 1, reason = "a" })
		pending_removals.enqueue(state, { row = 2, col = 3, reason = "b" })
		assert.are.equal(2, pending_removals.pending_count(state))
		local taken = pending_removals.take_all(state)
		assert.are.equal(0, pending_removals.pending_count(state))
		assert.are.equal(1, taken[1].row)
		assert.are.equal(3, taken[2].col)
	end)

	it("drains sacrifice after scoring leaves stone visible until drain", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.board[5][5] = board.make_stone(config.STONE_BLACK, "kamikaze_stone", 1, nil)
		state.last_opponent_move = { row = 5, col = 5, actor = "black", stone_id = "kamikaze_stone" }
		state.round_stone_effects = {
			{
				owner = config.OWNER_BLACK,
				stone_type = "kamikaze_stone",
				row = 5,
				col = 5,
				effects = content.get_stone("kamikaze_stone").effects,
			},
		}
		state.scores.points.B = 0
		resolve_round.resolve(state, { action = "on_play" })
		assert.is_false(board.is_empty(state.board[5][5]))
		assert.is_true(pending_removals.pending_count(state) > 0)
		remove_stones.run({ state = state, actor = "black", player_chain_color = config.STONE_BLACK })
		assert.is_true(board.is_empty(state.board[5][5]))
	end)

	it("skips on_removed for sacrifice entries on drain", function()
		local state = test_helper.new_isolated_game("basic_stones")
		state.scores = { points = { B = 1, W = 1 } }
		state.board[5][5] = board.make_stone(config.STONE_BLACK, "escalating_points_stone", 1, nil)
		state.board[5][5].stored_value = 10
		pending_removals.enqueue_sacrifice(state, 5, 5, { capturer = "white" })
		remove_stones.run({ state = state, actor = "white", player_chain_color = config.STONE_WHITE })
		local white = match_state.player_for_color(state, "white")
		assert.are.equal(1, white.score.points)
	end)
end)
