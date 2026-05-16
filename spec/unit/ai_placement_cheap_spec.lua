require("spec.test_helper")

local board = require("board")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local placement_cheap = require("ai.heuristics.placement_cheap")

describe("ai.heuristics.placement_cheap", function()
	it("top_by_cheap_score returns at most top_n moves", function()
		local g = match_state.new_match("pvc")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.players.white.stones.selected_stone = "stone_basic"
		local view = match_view.for_bot(g)
		local many = {}
		for r = 1, 9 do
			for c = 1, 9 do
				many[#many + 1] = { row = r, col = c }
			end
		end
		local top = placement_cheap.top_by_cheap_score(view, many, "stone_basic", nil, 8)
		assert.are.equal(8, #top)
	end)
end)
