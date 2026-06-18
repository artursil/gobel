--- Capture territory snapshot on placement for later multiplier payout.
--- @module objects.effects_conditions.effects.territory_to_multiplier_snapshot

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local territory_to_multiplier = require("objects.effects_conditions.helpers.shared.territory_to_multiplier")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "TERRITORY_TO_MULTIPLIER_SNAPSHOT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.mult,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, _owner, kwargs)
			local row = kwargs and kwargs.row
			local col = kwargs and kwargs.col
			if row == nil or col == nil then
				row, col = helpers.placement_coords(state)
			end
			territory_to_multiplier.capture_snapshot(state, row, col)
		end,
	}
end

return M
