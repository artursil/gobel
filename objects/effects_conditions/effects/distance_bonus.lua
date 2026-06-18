--- Mark distance bonus metadata consumed by board scan logic.
--- @module objects.effects_conditions.effects.distance_bonus

local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "DISTANCE_BONUS",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.territory,
		priority = effect.priority or 10,
		territory_step = effect.territory_step or "distance",
		value = effect.value,
		conditions = effect.conditions or {},
		apply = function(state, _owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col", "stone_def" })
			local key = helpers.stone_key(kwargs.row, kwargs.col)
			helpers.apply_distance_bonus_for_stone(
				kwargs.stone_def,
				state,
				key,
				config.BOARD_SIZE,
				effect.value
			)
		end,
	}
end

return M
