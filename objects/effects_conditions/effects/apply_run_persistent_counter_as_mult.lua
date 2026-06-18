--- Apply owner counter value as plus_mult.
--- @module objects.effects_conditions.effects.apply_run_persistent_counter_as_mult

local scheduling = require("objects.effects_conditions.scheduling")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or {}
	return {
		type = "APPLY_RUN_PERSISTENT_COUNTER_AS_MULT",
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
			local counters = state.run_state and state.run_state.counters
			local by_owner = counters and counters[counter_key]
			local bonus = by_owner and by_owner[owner] or 0
			state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + bonus
		end,
	}
end

return M
