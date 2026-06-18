--- Anti-capture on-play setup: grants ``duration_left`` on the placed connected own group.
---
--- Runs on ``on_play`` in the ``points`` phase. Definition must declare ``duration`` from parameters.
---
--- Shared helpers: ``anti_capture_setup.apply_on_play``.
---
--- No-op: missing placement coordinates.
--- @module objects.effects_conditions.effects.anti_capture_setup

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local anti_capture_setup = require("objects.effects_conditions.helpers.shared.anti_capture_setup")

local M = {}

--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local duration = effect.duration
	return {
		type = "ANTI_CAPTURE_SETUP",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			anti_capture_setup.apply_on_play(state, duration)
		end,
	}
end

return M
