--- Mark distance bonus metadata consumed by board scan logic.
--- @module objects.effects_conditions.effects.distance_bonus

local scheduling = require("objects.effects_conditions.scheduling")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "DISTANCE_BONUS",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.territory,
		priority = effect.priority or 10,
		territory_step = effect.territory_step or "distance",
		value = effect.value,
		conditions = effect.conditions or {},
	}
end

return M
