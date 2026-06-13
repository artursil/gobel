require("spec.test_helper")

local resolver = require("resolver")
local stone_placement_effects = require("ai.scoring.stone_placement_effects")

local EXPECTED_IMMEDIATE_PLACEMENT_EFFECT_NAMES = {
	"add_energy",
	"add_money",
	"add_mult",
	"add_points",
	"copper_threshold_plus_mult",
	"final_blow_placement",
	"kamikaze_sacrifice",
	"money_field_enclosure_payout",
	"mult_control_streak",
	"retrigger_prior_stone_effect",
	"self_destruct_timed",
}

describe("placement effect registry", function()
	it("resolver and AI placement scoring share immediate placement effect name keys", function()
		local resolver_keys = resolver.immediate_placement_effect_name_keys()
		local ai_keys = stone_placement_effects.immediate_placement_effect_name_keys()

		assert.are.same(ai_keys, resolver_keys)
		assert.are.same(EXPECTED_IMMEDIATE_PLACEMENT_EFFECT_NAMES, resolver_keys)
	end)
end)
