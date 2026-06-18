--- End-of-turn points payout derived from territory controlled by stone cell.
--- @module objects.effects_conditions.effects.territory_to_points

local board = require("board")
local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "TERRITORY_TO_POINTS",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.end_of_turn,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, _owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			local row = kwargs.row
			local col = kwargs.col
			local cell = state.board[row] and state.board[row][col]
			if not cell or board.is_empty(cell) or cell.kind ~= "territory_to_points_stone" then
				return
			end
			local territory_mod = require("single_game.resolver.territory")
			local territory_grid, territory_value = territory_mod.territory_map_for_stone_payout(state, row, col)
			if not territory_grid then
				return
			end
			local recipient = territory_mod.owner_at_cell(territory_grid, row, col)
			if not recipient then
				return
			end
			local owner_color = recipient == config.OWNER_WHITE and config.STONE_WHITE or config.STONE_BLACK
			local total_territory = territory_mod.weighted_territory_points(territory_grid, owner_color, territory_value)
			local payout = territory_mod.territory_to_points_payout(total_territory)
			if payout <= 0 then
				return
			end
			state.scores.points[recipient] = state.scores.points[recipient] + payout
		end,
	}
end

return M
