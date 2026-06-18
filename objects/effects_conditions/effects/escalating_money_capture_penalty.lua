--- On removal, deduct money based on previously tracked payouts.
--- @module objects.effects_conditions.effects.escalating_money_capture_penalty

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
		type = "ESCALATING_MONEY_CAPTURE_PENALTY",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_removed,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, _owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col", "cell" })
			local row = kwargs.row
			local col = kwargs.col
			local cell = kwargs.cell
			if not cell or board.is_empty(cell) then
				return
			end
			local received = helpers.stone_stored_value(state, row, col) or 0
			if cell.placed_via_play and received <= stone_params.ems_round_money then
				helpers.set_stone_stored_value(state, row, col, 0)
				return
			end
			if received <= 0 then
				helpers.set_stone_stored_value(state, row, col, 0)
				return
			end
			local side = cell.color == config.STONE_WHITE and "white" or "black"
			local player = require("match_state").player_for_color(state, side)
			local penalty = stone_params.ems_capture_multiplier * received
			require("economy").deduct_clamped(player.resources, penalty)
			helpers.set_stone_stored_value(state, row, col, 0)
		end,
	}
end

return M
