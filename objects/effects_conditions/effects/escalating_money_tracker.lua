--- End-of-turn recurring money payout and stored amount tracking.
--- @module objects.effects_conditions.effects.escalating_money_tracker

local board = require("board")
local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "ESCALATING_MONEY_TRACKER",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.end_of_turn,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			local row = kwargs.row
			local col = kwargs.col
			local cell = state.board[row] and state.board[row][col]
			if not cell or board.is_empty(cell) or cell.kind ~= "escalating_money_stone" then
				return
			end
			local stone_owner = cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
			if stone_owner ~= owner then
				return
			end
			if cell.placed_turn_number ~= nil and cell.placed_turn_number == (state.turn_number or 1) then
				return
			end
			if state._skip_board_end_of_turn_effects then
				return
			end
			local economy = require("economy")
			local side = owner == config.OWNER_WHITE and "white" or "black"
			local player = require("match_state").player_for_color(state, side)
			local round_money = stone_params.ems_round_money
			economy.gain(player.resources, round_money)
			local next_total = (helpers.stone_stored_value(state, row, col) or 0) + round_money
			helpers.set_stone_stored_value(state, row, col, next_total)
		end,
	}
end

return M
