--- Initialize escalating points bank to zero on placement.
--- @module objects.effects_conditions.effects.escalating_points_bank_init

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local escalating_points = require("objects.effects_conditions.helpers.shared.escalating_points")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "ESCALATING_POINTS_BANK_INIT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, _owner, kwargs)
			local row = kwargs and kwargs.row
			local col = kwargs and kwargs.col
			if row == nil or col == nil then
				row, col = helpers.placement_coords(state)
			end
			escalating_points.init_bank(state, row, col)
		end,
	}
end

return M
