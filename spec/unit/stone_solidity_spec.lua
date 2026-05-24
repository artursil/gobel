require("spec.test_helper")

local board = require("board")
local config = require("config")
local game = require("game")
local match_state = require("match_state")
local resolver = require("resolver")
local rules = require("rules")
local stone_params = require("objects.parameters.stones")
local stone_solidity = require("objects.stone_solidity")

describe("stone solidity", function()
	it("solidity_tier maps health bands for default max 4", function()
		assert.are.equal(0, stone_solidity.solidity_tier(4, 4))
		assert.are.equal(1, stone_solidity.solidity_tier(3, 4))
		assert.are.equal(2, stone_solidity.solidity_tier(2, 4))
		assert.are.equal(3, stone_solidity.solidity_tier(1, 4))
		assert.are.equal(3, stone_solidity.solidity_tier(0, 4))
	end)

	it("stone_max_solidity uses parameter default", function()
		assert.are.equal(stone_params.default_solidity, stone_solidity.stone_max_solidity("stone_basic"))
	end)

	it("make_stone and clone preserve solidity", function()
		local cell = board.make_stone(config.STONE_BLACK, "stone_basic", 2)
		assert.are.equal(2, cell.solidity)
		local b = board.new()
		b[1][1] = cell
		local copy = board.clone(b)
		assert.are.equal(2, copy[1][1].solidity)
		assert.is_true(board.equal(b, copy))
	end)

	it("make_stone without solidity defaults to max", function()
		local cell = board.make_stone(config.STONE_BLACK, "stone_basic")
		assert.are.equal(stone_solidity.stone_max_solidity("stone_basic"), cell.solidity)
	end)

	it("try_play sets full solidity on new stone", function()
		local b = board.new()
		local ok, trial = rules.try_play(b, 1, 1, config.STONE_BLACK, nil, "stone_power")
		assert.is_true(ok)
		assert.are.equal(stone_solidity.stone_max_solidity("stone_power"), trial[1][1].solidity)
	end)

	it("placement via resolver sets cell.solidity to max", function()
		local g = game.new("pvp", "basic_stones")
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local black = match_state.player_for_color(g, "black")
		black.stones.playable_stones = { "stone_basic" }
		black.stones.selected_stone = "stone_basic"
		black.stones.selected_stone_index = 1
		assert.is_true(resolver.submit_action(g, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 5, col = 5 },
		}).ok)
		local cell = g.board[5][5]
		assert.are.equal(stone_solidity.stone_max_solidity("stone_basic"), cell.solidity)
	end)
end)
