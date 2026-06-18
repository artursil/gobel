--- Anti-capture tick expire hook when ``duration_left`` reaches zero.
---
--- Runs on ``action = tick`` in the ``points`` phase. Clears timer state; stone remains on board.
--- Does not enqueue on ``pending_stone_removals``.
---
--- Shared helpers: ``duration_left``.
---
--- No-op: ``duration_left`` still counting.
--- @module objects.effects_conditions.effects.anti_capture_expire

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local duration_left = require("objects.effects_conditions.helpers.shared.duration_left")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "ANTI_CAPTURE_EXPIRE",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.tick,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "cell" })
			if duration_left.remaining(kwargs.cell) ~= 0 then
				return
			end
			duration_left.clear(kwargs.cell)
		end,
	}
end

return M
