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
end)
