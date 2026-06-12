require("spec.test_helper")

local board = require("board")
local config = require("config")
local game = require("game")
local match_state = require("match_state")
local resolver = require("resolver")
local test_helper = require("spec.test_helper")
local P = require("spec.parameters_helper")

describe("energy_stone placement", function()
	it("adds configured energy gain to player.energy on placement", function()
		local g = game.new("pvp", "basic_stones")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local player = match_state.player_for_color(g, "black")
		test_helper.set_hand(g, "black", { "energy_stone" })
		player.energy = 0
		player.energy_max = P.energy_max_default()

		local placed = resolver.submit_action(g, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 5, col = 5 },
		})

		assert.is_true(placed.ok)
		assert.are.equal(P.stone_energy_gain("energy_stone"), player.energy)
	end)

	it("clamps player.energy at energy_max when gain would exceed cap", function()
		local g = game.new("pvp", "basic_stones")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local player = match_state.player_for_color(g, "black")
		test_helper.set_hand(g, "black", { "energy_stone" })
		player.energy = P.energy_max_default()
		player.energy_max = P.energy_max_default()

		local placed = resolver.submit_action(g, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 5, col = 5 },
		})

		assert.is_true(placed.ok)
		assert.are.equal(P.energy_max_default(), player.energy)
	end)

	it("adds energy to placing player only", function()
		local g = game.new("pvp", "basic_stones")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		local white = match_state.player_for_color(g, "white")
		local black = match_state.player_for_color(g, "black")
		test_helper.set_hand(g, "white", { "energy_stone" })
		white.energy = 0
		black.energy = P.energy_max_default()

		local placed = resolver.submit_action(g, {
			actor = "white",
			type = "PLACE_STONE",
			payload = { row = 5, col = 5 },
		})

		assert.is_true(placed.ok)
		assert.are.equal(P.stone_energy_gain("energy_stone"), white.energy)
		assert.are.equal(P.energy_max_default(), black.energy)
	end)

	it("syncs resources.energy_current after energy_stone placement", function()
		local g = game.new("pvp", "basic_stones")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local player = match_state.player_for_color(g, "black")
		test_helper.set_hand(g, "black", { "energy_stone" })
		player.energy = 0
		player.energy_max = P.energy_max_default()

		local placed = resolver.submit_action(g, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 5, col = 5 },
		})

		assert.is_true(placed.ok)
		assert.are.equal(P.stone_energy_gain("energy_stone"), player.energy)
		assert.are.equal(player.energy, player.resources.energy_current)
	end)

	it("leaves player.energy unchanged when placement is rejected", function()
		local g = game.new("pvp", "basic_stones")
		g.board = board.new()
		g.board[5][5] = board.make_stone(config.STONE_BLACK, "stone_basic", 5)
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local player = match_state.player_for_color(g, "black")
		test_helper.set_hand(g, "black", { "energy_stone" })
		player.energy = 0
		player.energy_max = P.energy_max_default()

		local placed = resolver.submit_action(g, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 5, col = 5 },
		})

		assert.is_false(placed.ok)
		assert.are.equal(0, player.energy)
	end)

	it("does not change player.energy_max when gain is applied", function()
		local g = game.new("pvp", "basic_stones")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local player = match_state.player_for_color(g, "black")
		test_helper.set_hand(g, "black", { "energy_stone" })
		player.energy = 0
		player.energy_max = P.energy_max_default()
		local energy_max_before = player.energy_max

		local placed = resolver.submit_action(g, {
			actor = "black",
			type = "PLACE_STONE",
			payload = { row = 5, col = 5 },
		})

		assert.is_true(placed.ok)
		assert.are.equal(energy_max_before, player.energy_max)
	end)
end)
