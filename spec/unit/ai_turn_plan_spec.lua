require("spec.test_helper")

local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local plan = require("ai.turn.plan")

describe("ai.turn.plan", function()
	it("pops queued actions without replanning", function()
		local g = match_state.new_match("pvc")
		g.phase = "MAIN_PHASE"
		g.to_play = "white"
		local view = match_view.for_bot(g)
		plan.set(g, {
			{ actor = "white", type = "PLAY_CARD", payload = { hand_index = 1 } },
			{ actor = "white", type = "SELECT_STONE", payload = { stone_id = "stone_basic", stone_index = 1 } },
		})
		local first = plan.pop_valid(view)
		assert.are.equal("PLAY_CARD", first.type)
		local second = plan.pop_valid(view)
		assert.are.equal("SELECT_STONE", second.type)
		assert.is_nil(plan.pop_valid(view))
	end)
end)
