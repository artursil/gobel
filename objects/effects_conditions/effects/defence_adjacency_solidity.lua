--- Apply adjacency defence buff when a stone joins the network.
--- @module objects.effects_conditions.effects.defence_adjacency_solidity

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "DEFENCE_ADJACENCY_SOLIDITY",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, _owner, kwargs)
			local row = kwargs and kwargs.row
			local col = kwargs and kwargs.col
			if row == nil or col == nil then
				row, col = helpers.placement_coords(state)
			end
			if row and col then
				require("objects.defence_solidity_network").apply_adjacency_on_play(state, row, col)
			end
		end,
	}
end

return M
