--- Add energy for the current owner and clamp through shared helpers.
--- @module objects.effects_conditions.effects.add_energy

local scheduling = require("objects.effects_conditions.scheduling")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value
	return {
		type = "ADD_ENERGY",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or 10,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			helpers.gain_player_energy(state, owner, value)
		end,
	}
end

return M
