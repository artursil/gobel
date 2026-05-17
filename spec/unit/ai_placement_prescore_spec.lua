require("spec.test_helper")

local board = require("board")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local placement = require("ai.heuristics.placement")
local placement_cheap = require("ai.heuristics.placement_cheap")

describe("placement prescore_enabled", function()
	it("does not call top_by_cheap_score when prescore is disabled", function()
		local g = match_state.new_match("pvc")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.players.white.stones.selected_stone = "stone_basic"
		g.ai_placement = { prescore_enabled = false, full_eval_top_n = 2 }
		local view = match_view.for_bot(g)
		local candidates = {
			{ row = 3, col = 3 },
			{ row = 4, col = 4 },
			{ row = 5, col = 5 },
		}
		local called = false
		local original = placement_cheap.top_by_cheap_score
		placement_cheap.top_by_cheap_score = function()
			called = true
			return {}
		end
		placement.best_candidate(view, candidates, "stone_basic", nil, nil)
		placement_cheap.top_by_cheap_score = original
		assert.is_false(called)
	end)

	it("caps full evals to full_eval_top_n in filter order when prescore off", function()
		local g = match_state.new_match("pvc")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.players.white.stones.selected_stone = "stone_basic"
		g.ai_placement = { prescore_enabled = false, full_eval_top_n = 2 }
		local view = match_view.for_bot(g)
		local eval_count = 0
		local original = placement.evaluate_move
		placement.evaluate_move = function(v, row, col, stone_id, base, terr)
			eval_count = eval_count + 1
			return original(v, row, col, stone_id, base, terr)
		end
		local candidates = {
			{ row = 3, col = 3 },
			{ row = 4, col = 4 },
			{ row = 5, col = 5 },
		}
		placement.best_candidate(view, candidates, "stone_basic", nil, nil)
		placement.evaluate_move = original
		assert.are.equal(2, eval_count)
	end)
end)
