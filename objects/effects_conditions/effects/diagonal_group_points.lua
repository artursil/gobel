--- Award points for diagonally connected placement groups.
--- @module objects.effects_conditions.effects.diagonal_group_points

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "DIAGONAL_GROUP_POINTS",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.wall_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			require("objects.effects_conditions.helpers.shared.connected_group_placement").apply_diagonal(state, owner)
		end,
	}
end

return M
