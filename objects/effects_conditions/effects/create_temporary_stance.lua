--- Create a temporary stance object with configured stance id and rounds.
--- @module objects.effects_conditions.effects.create_temporary_stance

local scheduling = require("objects.effects_conditions.scheduling")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or {}
	return {
		type = "CREATE_TEMPORARY_STANCE",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or "hand",
		priority = effect.priority or 10,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			if not value.stance_id or not value.rounds then
				return
			end
			state.temporary_stances = state.temporary_stances or {}
			local ObjectInstance = require("single_game.resolver.ObjectInstance")
			local instance_id = "temp_stance_" .. state.turn_number .. "_" .. owner .. "_" .. #state.temporary_stances
			local temp_stance = ObjectInstance.new(
				instance_id,
				value.stance_id,
				"temporary_stance",
				owner,
				"created",
				{ remaining_rounds = value.rounds }
			)
			temp_stance.created_this_turn = true
			state.temporary_stances[#state.temporary_stances + 1] = temp_stance
		end,
	}
end

return M
