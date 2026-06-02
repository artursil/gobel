require("spec.test_helper")

local board = require("board")
local config = require("config")
local content = require("content")
local game = require("game")
local match_state = require("match_state")
local resolver = require("resolver")
local test_helper = require("spec.test_helper")

describe("stone upgrade placement", function()
	it("level 2 stone_power placement scores higher than level 1", function()
		local g = game.new("pvp", "stone_upgrade_test")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local player = match_state.player_for_color(g, "black")
		test_helper.set_stone_instance(g, "black", 1, "stone_power", 2)
		local points_before = player.score.points
		local placed = resolver.submit_action(g, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 5, col = 5 },
		})
		assert.is_true(placed.ok)
		local level1_value = content.resolve_stone({ def_id = "stone_power", level = 1 }).effects[1].value
		local level2_value = content.resolve_stone({ def_id = "stone_power", level = 2 }).effects[1].value
		assert.is_true(level2_value > level1_value)
		assert.are.equal(points_before + level2_value, player.score.points)
		assert.are.equal(2, g.board[5][5].level)
	end)
end)
