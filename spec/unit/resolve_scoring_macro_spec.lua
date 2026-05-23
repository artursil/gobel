require("spec.test_helper")

local board = require("board")
local config = require("config")
local game = require("game")
local match_state = require("match_state")
local resolve_round = require("single_game.resolver.resolve_round")
local resolver = require("resolver")
local spec_helper = require("spec.spec_helper")

describe("resolve scoring macro", function()
	it("playing_stones resolve counts center stone territory and placement points once", function()
		local g = game.new("pvp", "basic_stones")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local player = match_state.player_for_color(g, "black")
		player.stones.playable_stones = { "stone_basic" }
		player.stones.selected_stone = "stone_basic"
		player.stones.selected_stone_index = 1
		local ok, new_board = require("rules").try_play(g.board, 5, 5, config.STONE_BLACK, nil, "stone_basic")
		assert.is_true(ok)
		g.board = new_board
		g.round_stone_effects = {
			{
				owner = "B",
				stone_type = "stone_basic",
				effects = {
					{ effect_name = "add_points", macro = "playing_stones", sub = "points", value = 1, priority = 10 },
				},
			},
		}
		resolve_round.resolve(g, { macro = "playing_stones" })
		assert.are.equal(80, g.scores.territory.B)
		assert.are.equal(2, g.scores.points.B)
	end)

	it("card then stone macro path matches case_01 factors", function()
		local g = game.new("pvp", "basic_stones")
		g.board = board.new()
		g.phase = "MAIN_PHASE"
		g.to_play = "black"
		local player = match_state.player_for_color(g, "black")
		player.resources.energy_current = 3
		player.cards.hand.ids = { "card_point_tap" }
		player.stones.playable_stones = { "stone_basic" }
		player.stones.selected_stone = "stone_basic"
		player.stones.selected_stone_index = 1
		local played = resolver.submit_action(g, {
			actor = "black",
			type = "PLAY_CARD",
			payload = { hand_index = 1 },
		})
		assert.is_true(played.ok)
		assert.are.equal(3, player.score.points, "after card")
		assert.are.equal(3, g.scores.points.B, "state after card")
		g.phase = "PLACE_PHASE"
		local placed = resolver.submit_action(g, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 5, col = 5 },
		})
		assert.is_true(placed.ok)
		assert.are.equal(4, g.scores.points.B, "state after stone")
		assert.are.equal(4, player.score.points)
		assert.are.equal(80, player.score.territory)
		assert.are.equal(352, math.floor(player.score.total + 0.5))
	end)

	it("x_mult persists after opponent completes a turn", function()
		local g = game.new("pvp", "basic_x_stones")
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local black = match_state.player_for_color(g, "black")
		local white = match_state.player_for_color(g, "white")
		black.stones.playable_stones = { "x_stone" }
		black.stones.selected_stone = "x_stone"
		black.stones.selected_stone_index = 1

		local ok, board_after = require("rules").try_play(g.board, 5, 5, config.STONE_BLACK, nil, "x_stone")
		assert.is_true(ok)
		local diag = { { 4, 4 }, { 4, 6 }, { 6, 4 }, { 6, 6 } }
		for i = 1, #diag do
			local r, c = diag[i][1], diag[i][2]
			board_after[r][c] = board.make_stone(config.STONE_BLACK, "stone_basic")
		end
		g.board = board_after
		g.round_stone_effects = {
			{
				owner = "B",
				stone_type = "x_stone",
				effects = {},
			},
		}
		g.last_opponent_move = { row = 5, col = 5, stone_id = "x_stone", actor = "black" }
		resolve_round.resolve(g, { macro = "playing_stones" })
		assert.are.equal(2, black.score.x_mult, "completing minimal X doubles x_mult")

		g.to_play = "white"
		white.stones.playable_stones = { "stone_basic" }
		white.stones.selected_stone = "stone_basic"
		white.stones.selected_stone_index = 1
		g.phase = "PLACE_PHASE"
		local white_ok, white_board = require("rules").try_play(g.board, 3, 3, config.STONE_WHITE, nil, "stone_basic")
		assert.is_true(white_ok)
		g.board = white_board
		g.round_stone_effects = {
			{
				owner = "W",
				stone_type = "stone_basic",
				effects = {
					{ effect_name = "add_points", macro = "playing_stones", sub = "points", value = 1, priority = 10 },
				},
			},
		}
		g.last_opponent_move = { row = 3, col = 3, stone_id = "stone_basic", actor = "white" }
		resolve_round.resolve(g, { macro = "playing_stones" })
		resolve_round.resolve(g, { macro = "end_of_turn" })
		resolver.begin_turn(g, "black")
		assert.are.equal(2, black.score.x_mult, "black x_mult unchanged after white stone and turn advance")
	end)
end)
