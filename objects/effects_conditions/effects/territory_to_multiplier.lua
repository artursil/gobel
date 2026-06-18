--- Apply end-of-turn territory-based plus multiplier payout.
--- @module objects.effects_conditions.effects.territory_to_multiplier

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")
local territory_to_multiplier = require("objects.effects_conditions.helpers.shared.territory_to_multiplier")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "TERRITORY_TO_MULTIPLIER",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.end_of_turn,
		phase = phase or scheduling.PHASE.mult,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, _owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			territory_to_multiplier.apply_end_of_turn(state, kwargs.row, kwargs.col)
		end,
	}
end

return M
