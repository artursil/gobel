require("spec.test_helper")

local board = require("board")
local goals = require("ai.heuristics.goals")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local placement = require("ai.heuristics.placement")

describe("ai.heuristics.goals wiring", function()
	it("candidate_bonus changes evaluate_move ordering", function()
		local g = match_state.new_match("pvc")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.players.white.stones.selected_stone = "stone_basic"
		local view = match_view.for_bot(g)
		local a = placement.evaluate_move(view, 3, 3, "stone_basic")
		local b = placement.evaluate_move(view, 5, 5, "stone_basic")
		assert.is_not_nil(a)
		assert.is_not_nil(b)
		local base_a, base_b = a.score, b.score

		goals._test_bonus = 100
		local a2 = placement.evaluate_move(view, 3, 3, "stone_basic")
		local b2 = placement.evaluate_move(view, 5, 5, "stone_basic")
		goals._test_bonus = nil

		assert.is_true(a2.score >= base_a + 100)
		assert.is_true(b2.score >= base_b + 100)
	end)
end)
