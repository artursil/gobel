--- Add plus multiplier for the current owner.
--- @module objects.effects_conditions.effects.add_mult

local scheduling = require("objects.effects_conditions.scheduling")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value
	return {
		type = "ADD_MULT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.mult,
		priority = effect.priority or 10,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + value
		end,
	}
end

return M
