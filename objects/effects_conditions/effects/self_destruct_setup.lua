--- Self-destruct on-play setup: immediate points and ``duration_left`` removal timer.
---
--- Runs on ``on_play`` in the ``points`` phase. Definition must declare ``immediate_points`` and
--- ``delay_rounds`` from parameters.
---
--- Shared helpers: ``self_destruct_timed.setup_on_play``.
---
--- No-op: missing placement coordinates or empty cell.
--- @module objects.effects_conditions.effects.self_destruct_setup

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local self_destruct = require("objects.effects_conditions.helpers.shared.self_destruct_timed")

local M = {}

--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local immediate_points = effect.immediate_points
	local delay_rounds = effect.delay_rounds
	return {
		type = "SELF_DESTRUCT_SETUP",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		value = immediate_points,
		delay_rounds = delay_rounds,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			self_destruct.setup_on_play(
				state,
				owner,
				immediate_points,
				delay_rounds,
				kwargs and kwargs.row,
				kwargs and kwargs.col
			)
		end,
	}
end

return M
