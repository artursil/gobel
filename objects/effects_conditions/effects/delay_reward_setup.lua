--- Delay-reward on-play setup: stores ``duration_left`` on the placed cell.
---
--- Runs on ``on_play`` in the ``points`` phase. Definition must declare ``rounds`` and ``payout``
--- from parameters (no builder fallback).
---
--- Shared helpers: ``delay_reward.setup_from_placement``.
---
--- No-op: missing placement coordinates or empty cell.
--- @module objects.effects_conditions.effects.delay_reward_setup

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local delay_reward = require("objects.effects_conditions.helpers.shared.delay_reward")

local M = {}

--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local rounds = effect.rounds
	local payout = effect.payout
	return {
		type = "DELAY_REWARD_SETUP",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			delay_reward.setup_from_placement(
				state,
				owner,
				rounds,
				kwargs and kwargs.row,
				kwargs and kwargs.col
			)
		end,
	}
end

return M
