--- Capture stone supplemental removal: enqueue condition-selected enemy cell.
---
--- Runs on ``on_play`` in the ``points`` phase after regular Go captures at commit.
--- Requires ``capture_stone_supplemental_target`` condition supplying ``{ row, col }``.
--- Enqueues on ``pending_stone_removals`` and awards capture bonus points; drain runs
--- in the on-play removal beat after scoring animations.
---
--- Definition fields: ``priority`` defaults to ``stone_params.default_effect_priority``.
---
--- Kwargs: ``row``, ``col`` (required) from supplemental target condition.
---
--- Shared helpers: ``require_kwargs``, ``pending_removals``.
---
--- No-op: missing target coordinates.
--- @module objects.effects_conditions.effects.capture_zero_liberty_enemy

local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")

local M = {}

--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "CAPTURE_ZERO_LIBERTY_ENEMY",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			local capturer = owner == config.OWNER_BLACK and "black" or "white"
			pending_removals.enqueue(state, {
				row = kwargs.row,
				col = kwargs.col,
				capturer = capturer,
				reason = "capture_stone_supplemental",
			})
			state.scores.points[owner] = state.scores.points[owner] + stone_params.capture_bonus_points_per_stone
		end,
	}
end

return M
