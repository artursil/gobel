require("spec.test_helper")

local ai_config = require("ai.config")

describe("ai.config", function()
	it("apply_profile sets normal PVC defaults", function()
		local g = {}
		ai_config.apply_profile(g, "normal")
		assert.are.equal("normal", g.ai_difficulty)
		assert.is_true(g.ai_planner_enabled)
		assert.are.equal(12, g.ai_planner_max_scripts)
		local profile = ai_config.profiles.normal
		assert.are.equal(profile.mcts.enabled, g.ai_mcts.enabled)
		assert.are.equal(profile.placement.candidate_k, g.ai_placement.candidate_k)
		assert.are.equal(profile.placement.full_eval_top_n, g.ai_placement.full_eval_top_n)
		assert.are.equal(profile.placement.prescore_enabled, g.ai_placement.prescore_enabled)
		assert.are.equal("margin", g.ai_scoring.decision_mode)
	end)

	it("for_game merges per-match overrides on top of profile", function()
		local g = {}
		ai_config.apply_profile(g, "normal")
		g.ai_placement = { full_eval_top_n = 3 }
		g.ai_mcts = { iterations = 99 }
		g.ai_planner_max_scripts = 5
		local s = ai_config.for_game(g)
		assert.are.equal(3, s.placement.full_eval_top_n)
		assert.are.equal(ai_config.profiles.normal.placement.candidate_k, s.placement.candidate_k)
		assert.are.equal(99, s.mcts.iterations)
		assert.are.equal(5, s.planner.max_scripts)
	end)

	it("hard profile enables MCTS with time budget", function()
		local g = {}
		ai_config.apply_profile(g, "hard")
		local s = ai_config.for_game(g)
		assert.is_true(s.mcts.enabled)
		assert.are.equal(20, s.mcts.iterations)
		assert.are.equal(100, s.mcts.max_decision_ms)
	end)
end)
