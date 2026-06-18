--- Apply territory override ownership to orthogonally adjacent empty cells.
--- @module objects.effects_conditions.effects.control_territory_override

local scheduling = require("objects.effects_conditions.scheduling")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")
local control_override = require("objects.effects_conditions.helpers.shared.control_territory_override")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "CONTROL_TERRITORY_OVERRIDE",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.territory,
		priority = effect.priority or 10,
		territory_step = effect.territory_step or "override",
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			control_override.apply_at(state, owner, kwargs.row, kwargs.col)
		end,
	}
end

return M
