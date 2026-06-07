require("spec.test_helper")

local board = require("board")
local config = require("config")
local game = require("game")
local match_state = require("match_state")
local resolver = require("resolver")
local P = require("spec.parameters_helper")

--- @param events table
--- @return integer
local function capture_score_event_total(events)
	local total = 0
	for i = 1, #(events or {}) do
		local event = events[i]
		if event.kind == "points" and event.source == "capture" then
			total = total + event.value
		end
	end
	return total
end

describe("capture bonus compile injection", function()
	--- @param stone_id string
	--- @param board_before table
	--- @param row integer
	--- @param col integer
	--- @return table result_game
	--- @return table submit_result
	--- @return number points_before
	local function place_capture_with_stone(stone_id, board_before, row, col)
		local g = game.new("pvp", "basic_stones")
		g.board = board_before
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local player = match_state.player_for_color(g, "black")
		player.stones.playable_stones = { stone_id }
		player.stones.selected_stone = stone_id
		player.stones.selected_stone_index = 1
		local points_before = player.score.points or 0
		g.messages.score_events = {}
		local result = resolver.submit_action(g, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = row, col = col },
		})
		return g, result, points_before
	end

	it("awards capture_bonus_points_per_stone for a single capture with stone_basic", function()
		local b = board.new()
		b[5][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[5][6] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[5][5] = board.make_stone(config.STONE_WHITE, "stone_basic")
		b[6][5] = board.make_stone(config.STONE_BLACK, "stone_basic")

		local g, result, points_before = place_capture_with_stone("stone_basic", b, 4, 5)
		assert.is_true(result.ok)
		local player = match_state.player_for_color(g, "black")
		assert.are.equal(points_before + P.capture_bonus_points(1), player.score.points)
		assert.are.equal(P.capture_bonus_points(1), capture_score_event_total(g.messages.score_events))
	end)

	it("awards bonus per captured stone for multi-stone group capture", function()
		local b = board.new()
		b[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[4][5] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[4][6] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[4][7] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[5][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[5][5] = board.make_stone(config.STONE_WHITE, "stone_basic")
		b[5][6] = board.make_stone(config.STONE_WHITE, "stone_basic")
		b[5][7] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[6][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[6][6] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[6][7] = board.make_stone(config.STONE_BLACK, "stone_basic")

		local g, result, points_before = place_capture_with_stone("stone_basic", b, 6, 5)
		assert.is_true(result.ok)
		local player = match_state.player_for_color(g, "black")
		assert.are.equal(points_before + P.capture_bonus_points(2), player.score.points)
		assert.are.equal(P.capture_bonus_points(2), capture_score_event_total(g.messages.score_events))
	end)

	it("adds no capture bonus when placement removes zero enemy stones", function()
		local b = board.new()
		local g, result, points_before = place_capture_with_stone("stone_basic", b, 5, 5)
		assert.is_true(result.ok)
		local player = match_state.player_for_color(g, "black")
		assert.are.equal(points_before, player.score.points)
		assert.are.equal(0, capture_score_event_total(g.messages.score_events))
	end)

	it("stone_power stacks placement points with capture bonus", function()
		local b = board.new()
		b[5][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[5][6] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[5][5] = board.make_stone(config.STONE_WHITE, "stone_basic")
		b[6][5] = board.make_stone(config.STONE_BLACK, "stone_basic")

		local g, result, points_before = place_capture_with_stone("stone_power", b, 4, 5)
		assert.is_true(result.ok)
		local player = match_state.player_for_color(g, "black")
		local expected = points_before + P.stone_points("stone_power") + P.capture_bonus_points(1)
		assert.are.equal(expected, player.score.points)
		assert.are.equal(P.capture_bonus_points(1), capture_score_event_total(g.messages.score_events))
	end)
end)
