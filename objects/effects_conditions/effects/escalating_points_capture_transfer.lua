--- Transfer banked points to captor on removal and clear bank.
--- @module objects.effects_conditions.effects.escalating_points_capture_transfer

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")
local escalating_points = require("objects.effects_conditions.helpers.shared.escalating_points")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "ESCALATING_POINTS_CAPTURE_TRANSFER",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_removed,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, _owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col", "cell" })
			escalating_points.apply_capture_transfer(state, kwargs.row, kwargs.col, kwargs.cell, kwargs.opts)
		end,
	}
end

return M
