--- Self-destruct tick expire: enqueue removal on ``pending_stone_removals`` at timer zero.
---
--- Runs on ``action = tick`` in the ``points`` phase. Drain runs after the EOT animation stub.
---
--- Shared helpers: ``self_destruct_timed.expire_at_zero``.
---
--- No-op: ``duration_left`` still counting.
--- @module objects.effects_conditions.effects.self_destruct_expire

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local self_destruct = require("objects.effects_conditions.helpers.shared.self_destruct_timed")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "SELF_DESTRUCT_EXPIRE",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.tick,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col", "cell" })
			self_destruct.expire_at_zero(state, kwargs.row, kwargs.col, kwargs.cell)
		end,
	}
end

return M
