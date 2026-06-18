--- Award kamikaze points and queue self removal of the placed stone.
--- @module objects.effects_conditions.effects.kamikaze_sacrifice

local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or stone_params.kamikaze_points_bonus
	return {
		type = "KAMIKAZE_SACRIFICE",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			state.scores.points[owner] = state.scores.points[owner] + value
			local capturer = owner == config.OWNER_BLACK and "black" or "white"
			pending_removals.enqueue_sacrifice(state, kwargs.row, kwargs.col, { capturer = capturer })
		end,
	}
end

return M
