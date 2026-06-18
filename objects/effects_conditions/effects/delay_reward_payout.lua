--- Delay-reward tick payout when ``duration_left`` reaches zero after generic decrement.
---
--- Runs on ``action = tick`` in the ``points`` phase for cells with an active timer.
--- Pays deferred payout from the stone definition and clears timer fields.
---
--- Shared helpers: ``delay_reward.payout_at_zero``.
---
--- No-op: ``duration_left`` still counting or payout already cleared.
--- @module objects.effects_conditions.effects.delay_reward_payout

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local delay_reward = require("objects.effects_conditions.helpers.shared.delay_reward")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "DELAY_REWARD_PAYOUT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.tick,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col", "cell" })
			delay_reward.payout_at_zero(state, kwargs.row, kwargs.col, kwargs.cell)
		end,
	}
end

return M
