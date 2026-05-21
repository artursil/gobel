require("spec.test_helper")

local ai_config = require("ai.config")
local stone_heuristics_def = require("ai.heuristics.stone_heuristics_def")

describe("ai.heuristics.placement registry", function()
	it("registry re-exports stone_heuristics_def TERMS", function()
		assert.is_table(stone_heuristics_def.TERMS.delta_territory_me)
		assert.are.equal("delta_territory_me", stone_heuristics_def.TERMS.delta_territory_me.id)
	end)

	it("legacy heuristics on game still filters selection via for_game", function()
		local g = {}
		ai_config.apply_profile(g, "normal")
		g.ai_placement.heuristics = {
			{ id = "delta_captures", enabled = false },
			{ id = "delta_territory_me", enabled = true },
		}
		local s = ai_config.for_game(g)
		local found = false
		for i = 1, #s.placement.heuristics do
			if s.placement.heuristics[i].id == "delta_captures" then
				found = true
				assert.is_false(s.placement.heuristics[i].enabled)
			end
		end
		assert.is_true(found)
	end)
end)
