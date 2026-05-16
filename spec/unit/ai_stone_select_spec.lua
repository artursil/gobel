require("spec.test_helper")

local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local stone_select = require("ai.heuristics.stone_select")

describe("ai.heuristics.stone_select", function()
	it("returns a valid index from playable stones", function()
		local g = match_state.new_match("pvc")
		g.players.white.stones.playable_stones = { "stone_basic", "stone_special", "stone_focus" }
		local view = match_view.for_bot(g)
		local idx = stone_select.choose_index(view)
		assert.is_true(idx >= 1 and idx <= 3)
		assert.are.equal("stone_special", g.players.white.stones.playable_stones[idx])
	end)
end)
