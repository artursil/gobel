require("spec.test_helper")

local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local planner = require("ai.turn.planner")

describe("ai.turn.planner", function()
	it("prefers play_card when an affordable card outscores skip", function()
		local g = match_state.new_match("pvc")
		g.phase = "MAIN_PHASE"
		g.to_play = "white"
		g.players.white.cards.hand.ids = { "card_point_tap" }
		g.players.white.resources.energy_current = 3
		local view = match_view.for_bot(g)
		local steps = planner.build_plan(view)
		assert.is_true(#steps >= 1)
		assert.are.equal("PLAY_CARD", steps[1].type)
		assert.are.equal(1, steps[1].payload.hand_index)
	end)
end)
