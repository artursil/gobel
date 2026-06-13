require("spec.test_helper")

local board = require("board")
local config = require("config")
local game = require("game")
local match_state = require("match_state")
local resolver = require("resolver")
local P = require("spec.parameters_helper")

--- @param stone_id string
--- @param board_before table
--- @param row integer
--- @param col integer
--- @param actor string
--- @return table result_game
--- @return table submit_result
--- @return number points_before
local function place_stone_for_actor(stone_id, board_before, row, col, actor)
	local g = game.new("pvp", "basic_stones")
	g.board = board_before
	g.phase = "PLACE_PHASE"
	g.to_play = actor
	local player = match_state.player_for_color(g, actor)
	player.stones.playable_stones = { stone_id }
	player.stones.selected_stone = stone_id
	player.stones.selected_stone_index = 1
	local points_before = player.score.points or 0
	local result = resolver.submit_action(g, {
		actor = actor,
		type = "PLACE_STONE",
		payload = { row = row, col = col },
	})
	return g, result, points_before
end

describe("kamikaze_stone sacrifice placement", function()
	it("pays kamikaze_points_bonus and self-removes on an open board", function()
		local g, result, points_before = place_stone_for_actor("kamikaze_stone", board.new(), 5, 5, "black")
		assert.is_true(result.ok)
		local player = match_state.player_for_color(g, "black")
		assert.are.equal(points_before + P.kamikaze_points_bonus(), player.score.points)
		assert.is_true(board.is_empty(g.board[5][5]))
	end)

	it("pays kamikaze_points_bonus and self-removes when the cell has liberties", function()
		local b = board.new()
		b[5][4] = board.make_stone(config.STONE_BLACK, "stone_basic")

		local g, result, points_before = place_stone_for_actor("kamikaze_stone", b, 5, 5, "black")
		assert.is_true(result.ok)
		local player = match_state.player_for_color(g, "black")
		assert.are.equal(points_before + P.kamikaze_points_bonus(), player.score.points)
		assert.is_true(board.is_empty(g.board[5][5]))
		assert.is_false(board.is_empty(g.board[5][4]))
	end)
end)
