require("spec.test_helper")

local config = require("config")
local animation_schedule = require("ui.animation_schedule")

local function shake(seq, dur, delay, parallel)
	return {
		type = "stance_shake",
		owner = config.OWNER_BLACK,
		stance_slot_index = 1,
		sequence_id = seq,
		duration_ms = dur,
		start_delay_ms = delay or 0,
		parallel = parallel,
	}
end

describe("ui.animation_schedule effective_start_ms_list", function()
	it("chains three sequential intents with same sequence_id at 0, 100, 200 ms when each duration is 100", function()
		local intents = {
			shake("seq_a", 100, 0, false),
			shake("seq_a", 100, 0, false),
			shake("seq_a", 100, 0, false),
		}
		local eff = animation_schedule.effective_start_ms_list(intents)
		assert.are.same({ 0, 100, 200 }, eff)
	end)

	it("middle parallel true: first and second at 0, third non-parallel starts after first sequential block ends", function()
		local intents = {
			shake("seq_b", 100, 0, false),
			shake("seq_b", 100, 0, true),
			shake("seq_b", 100, 0, false),
		}
		local eff = animation_schedule.effective_start_ms_list(intents)
		assert.are.same({ 0, 0, 100 }, eff)
	end)

	it("intents without sequence_id use only start_delay_ms", function()
		local intents = {
			{ type = "stance_shake", owner = config.OWNER_BLACK, stance_slot_index = 1, duration_ms = 50, start_delay_ms = 7 },
			{ type = "stance_shake", owner = config.OWNER_BLACK, stance_slot_index = 1, duration_ms = 50, start_delay_ms = 3 },
		}
		local eff = animation_schedule.effective_start_ms_list(intents)
		assert.are.same({ 7, 3 }, eff)
	end)
end)
