--- Add flat points to the current owner during scoring.
--- @module objects.effects_conditions.effects.add_points

local scheduling = require("objects.effects_conditions.scheduling")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value
	return {
		type = "ADD_POINTS",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or 10,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			state.scores.points[owner] = state.scores.points[owner] + value
		end,
	}
end

return M
