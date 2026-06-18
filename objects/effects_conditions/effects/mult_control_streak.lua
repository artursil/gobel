--- Add plus_mult from territory control streak snapshot.
--- @module objects.effects_conditions.effects.mult_control_streak

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "MULT_CONTROL_STREAK",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.mult,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local territory_control_rounds = require("single_game.resolver.helpers.territory_control_rounds")
			local streak = territory_control_rounds.placement_streak_snapshot(state)
			local delta = territory_control_rounds.plus_mult_delta_for_streak(streak, state, owner)
			if delta ~= 0 then
				state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + delta
			end
		end,
	}
end

return M
