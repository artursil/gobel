--- Adjust owner-scoped run-persistent counter and pending delta.
--- @module objects.effects_conditions.effects.adjust_run_persistent_counter

local scheduling = require("objects.effects_conditions.scheduling")
local stance_params = require("objects.parameters.stances")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or {}
	return {
		type = "ADJUST_RUN_PERSISTENT_COUNTER",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.mult,
		priority = effect.priority or 10,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local counter_key = value.counter_key
			if not counter_key or owner == nil then
				return
			end
			state.run_state = state.run_state or {}
			state.run_state.counters = state.run_state.counters or {}
			state.run_state.counters[counter_key] = state.run_state.counters[counter_key] or { B = 0, W = 0 }
			local delta = value.delta or 0
			local old = state.run_state.counters[counter_key][owner]
			local new_val = math.max(stance_params.stance_persistent_flux_counter_floor, old + delta)
			local effective = new_val - old
			state.run_state.counters[counter_key][owner] = new_val
			state.run_state.pending_counter_mult_delta = state.run_state.pending_counter_mult_delta or {}
			state.run_state.pending_counter_mult_delta[counter_key] = state.run_state.pending_counter_mult_delta[counter_key]
				or { B = 0, W = 0 }
			state.run_state.pending_counter_mult_delta[counter_key][owner] = state.run_state.pending_counter_mult_delta[counter_key][owner]
				+ effective
		end,
	}
end

return M
