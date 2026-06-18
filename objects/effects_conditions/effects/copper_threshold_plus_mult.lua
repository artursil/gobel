--- Add plus_mult when copper threshold condition has already passed.
--- @module objects.effects_conditions.effects.copper_threshold_plus_mult

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or stone_params.copper_threshold_plus_mult_bonus
	return {
		type = "COPPER_THRESHOLD_PLUS_MULT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.mult,
		priority = effect.priority or stone_params.default_effect_priority,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local row, col = helpers.placement_coords(state)
			if not row or not col then
				return
			end
			state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + value
		end,
	}
end

return M
