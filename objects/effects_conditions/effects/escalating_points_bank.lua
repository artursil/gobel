--- Add recurring points to bank and owner each end of turn.
--- @module objects.effects_conditions.effects.escalating_points_bank

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")
local escalating_points = require("objects.effects_conditions.helpers.shared.escalating_points")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local round_points = effect.value or stone_params.eps_round_points
	return {
		type = "ESCALATING_POINTS_BANK",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.end_of_turn,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		value = effect.value,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			escalating_points.apply_end_of_turn_bank(state, owner, kwargs.row, kwargs.col, round_points)
		end,
	}
end

return M
