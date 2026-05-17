require("spec.test_helper")

describe("ai package", function()
	it("does not reference resolve_round under ai/turn or ai/heuristics", function()
		local paths = {
			"ai/turn/planner.lua",
			"ai/turn/scripts.lua",
			"ai/turn/plan.lua",
			"ai/heuristics/registry.lua",
			"ai/heuristics/cards.lua",
			"ai/heuristics/targets.lua",
			"ai/heuristics/synergy.lua",
		}
		for i = 1, #paths do
			local f = io.open(paths[i], "r")
			assert.is_not_nil(f, paths[i])
			local text = f:read("*a")
			f:close()
			assert.is_nil(string.find(text, 'require("single_game.resolver.resolve_round"', 1, true), paths[i])
			assert.is_nil(string.find(text, "resolve_round.resolve", 1, true), paths[i])
		end
	end)
end)
