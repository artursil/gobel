require("spec.test_helper")

local config = require("config")
local game = require("game")
local match_state = require("match_state")
local resolve_round = require("single_game.resolver.resolve_round")
local test_helper = require("spec.test_helper")

describe("tower territory score through resolve", function()
	local LETTER_TO_STONE = {
		T = { color = config.STONE_BLACK, kind = "stone_tower" },
	}

	test_helper.set_visual_board_letters(LETTER_TO_STONE, { T = "T" })

	local EMPTY = {
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
	}

	local TOWER = {
		"T . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
		". . . . . . . . .",
	}

	local function new_game()
		local g = game.new("pvp", "basic_stones")
		g.phase = "PLACE_PHASE"
		g.to_play = "black"
		local black = match_state.player_for_color(g, "black")
		black.stones.playable_stones = { "stone_tower" }
		black.stones.selected_stone = "stone_tower"
		black.stones.selected_stone_index = 1
		return g
	end

	local function place_corner_tower(g)
		test_helper.set_board(g, EMPTY)
		test_helper.place_stone(g, TOWER, false)
	end

	it("player.score.territory uses weighted territory_value after tower placement", function()
		local g = new_game()
		place_corner_tower(g)

		assert.are.equal(2, g.territory_value[1][2])
		assert.are.equal(2, g.territory_value[2][1])
		assert.are.equal(2, g.territory_value[2][2])

		local expected = test_helper.player_territory_score(g, "black")
		local black = match_state.player_for_color(g, "black")
		assert.are.equal(expected, black.score.territory)
		assert.is_true(black.score.territory > 81, "weighted corner block exceeds plain cell count")
	end)

	it("tower weights persist after playing_cards resolve in same turn", function()
		local g = new_game()
		place_corner_tower(g)

		local after_stone = test_helper.player_territory_score(g, "black")
		resolve_round.resolve(g, { action = "on_card" })

		assert.are.equal(2, g.territory_value[1][2])
		assert.are.equal(after_stone, match_state.player_for_color(g, "black").score.territory)
		assert.are.equal(after_stone, match_state.player_for_color(g, "black").score.territory)
		assert.is_true(match_state.player_for_color(g, "black").score.territory > 81)
	end)

	it("tower weights persist on end_of_turn resolve", function()
		local g = new_game()
		place_corner_tower(g)

		resolve_round.resolve(g, { action = "end_of_turn" })

		assert.are.equal(2, g.territory_value[1][2])
		assert.are.equal(test_helper.player_territory_score(g, "black"), match_state.player_for_color(g, "black").score.territory)
	end)
end)
