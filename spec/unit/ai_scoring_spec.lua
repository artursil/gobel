require("spec.test_helper")

local ai_config = require("ai.config")
local ai_scoring = require("ai.scoring")
local evaluate = require("ai.board_analysis.evaluate")

describe("ai.scoring", function()
	it("combine returns margin when decision_mode is margin", function()
		assert.are.equal(3, ai_scoring.combine(10, 7, "margin"))
		assert.are.equal(10, ai_scoring.combine(10, 7, "absolute"))
	end)

	it("for_game merges ai_scoring override", function()
		local g = {}
		ai_config.apply_profile(g, "normal")
		g.ai_scoring = { decision_mode = "margin" }
		assert.are.equal("margin", ai_scoring.decision_mode(g))
	end)

	it("normalize_result differs between absolute and margin modes", function()
		local margin_norm = evaluate.normalize_result(20, 5, "margin")
		local absolute_norm = evaluate.normalize_result(20, 5, "absolute")
		assert.are.equal(0.5 + 15 / 40, margin_norm)
		assert.are.equal(0.5 + 20 / 40, absolute_norm)
	end)
end)
