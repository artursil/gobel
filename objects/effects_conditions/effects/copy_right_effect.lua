--- Replay right-neighbor stance effects for the active phase.
--- @module objects.effects_conditions.effects.copy_right_effect

local scheduling = require("objects.effects_conditions.scheduling")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	if phase == "distance" then
		phase = scheduling.PHASE.territory
	end
	phase = phase or effect.phase or scheduling.PHASE.points
	return {
		type = "COPY_RIGHT_EFFECT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase,
		priority = effect.priority or 10,
		territory_step = effect.territory_step,
		value = effect.value,
		conditions = effect.conditions or {},
		apply = function(state, _owner, _kwargs)
			local copy_right = require("objects.effects_conditions.helpers.shared.copy_right")
			copy_right.apply_copy_right(state, require("objects.effects_conditions.effects").resolve)
		end,
	}
end

return M
