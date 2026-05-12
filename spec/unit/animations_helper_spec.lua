require("spec.test_helper")

local config = require("config")
local animations_helper = require("objects.animations_helper")

describe("objects.animations_helper", function()
	it("get_stance_index returns resolution slot when owner matches", function()
		local state = {
			resolution = { source_owner = config.OWNER_BLACK, source_stance_slot_index = 3 },
		}
		assert.are.equal(3, animations_helper.get_stance_index(state, config.OWNER_BLACK))
	end)

	it("get_stance_index returns 1 when owner mismatches", function()
		local state = {
			resolution = { source_owner = config.OWNER_WHITE, source_stance_slot_index = 2 },
		}
		assert.are.equal(1, animations_helper.get_stance_index(state, config.OWNER_BLACK))
	end)

	it("steel_hand_float_step_duration_ms: N=1 yields 1200", function()
		assert.are.equal(1200, animations_helper.steel_hand_float_step_duration_ms(1))
	end)

	it("steel_hand_float_step_duration_ms: N=3 yields 400 each", function()
		assert.are.equal(400, animations_helper.steel_hand_float_step_duration_ms(3))
	end)

	it("steel_hand_float_step_duration_ms: N=10 min forces 200 each and total exceeds budget", function()
		local per = animations_helper.steel_hand_float_step_duration_ms(10)
		assert.are.equal(200, per)
		assert.are.equal(2000, 10 * per)
	end)
end)
