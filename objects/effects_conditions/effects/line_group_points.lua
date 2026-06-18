--- Award points for orthogonally connected line-stone groups.
--- @module objects.effects_conditions.effects.line_group_points

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local stone_kind = effect.stone_kind or "line_stone"
	return {
		type = "LINE_GROUP_POINTS",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.wall_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			require("objects.effects_conditions.helpers.shared.connected_group_placement").apply_line(state, owner, stone_kind)
		end,
	}
end

return M
