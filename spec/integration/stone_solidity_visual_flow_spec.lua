local helper = require("spec.test_helper")

helper.install_love_test_stubs()

local board = require("board")
local config = require("config")
local game = require("game")
local match_state = require("match_state")
local render = require("render")
local resolver = require("resolver")

describe("Stone solidity visual flow", function()
	it("updates visual tier after attack then heal on same stone", function()
		local g = game.new("pvp")
		g.phase = "MAIN_PHASE"
		g.to_play = "white"
		local white = match_state.player_for_color(g, "white")
		local black = match_state.player_for_color(g, "black")
		white.cards.hand.ids = { "card_attack_1" }
		black.cards.hand.ids = { "card_heal_1" }
		white.energy = 10
		black.energy = 10
		g.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic", 4)
		local attack = resolver.submit_action(g, {
			actor = "white",
			type = "PLAY_CARD",
			payload = {
				hand_index = 1,
				selected_targets = {
					{ object_type = "stone", row = 4, col = 4 },
				},
			},
		})
		assert.is_true(attack.ok, attack.error)
		assert.are.equal(3, g.board[4][4].solidity)
		assert.are.equal(1, render.stone_visual_tier(g.board[4][4].kind, g.board[4][4].solidity))
		g.to_play = "black"
		g.phase = "MAIN_PHASE"
		local heal = resolver.submit_action(g, {
			actor = "black",
			type = "PLAY_CARD",
			payload = {
				hand_index = 1,
				selected_targets = {
					{ object_type = "stone", row = 4, col = 4 },
				},
			},
		})
		assert.is_true(heal.ok, heal.error)
		assert.are.equal(4, g.board[4][4].solidity)
		assert.are.equal(0, render.stone_visual_tier(g.board[4][4].kind, g.board[4][4].solidity))
	end)
end)
