--- Final-round placement bonus with non-final fallback points.
--- @module objects.effects_conditions.effects.final_blow_placement

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "FINAL_BLOW_PLACEMENT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			if helpers.is_final_round(state) then
				state.scores.points[owner] = state.scores.points[owner] + stone_params.final_blow_points
				state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + stone_params.final_blow_plus_mult
				return
			end
			state.scores.points[owner] = state.scores.points[owner] + stone_params.final_blow_nonfinal_points
		end,
	}
end

return M
