--- Add money when placement lands inside owner enclosure.
--- @module objects.effects_conditions.effects.money_field_enclosure_payout

local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "MONEY_FIELD_ENCLOSURE_PAYOUT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local row, col = helpers.placement_coords(state)
			if not row or not col then
				return
			end
			local enclosure_placement = require("single_game.resolver.enclosure_placement")
			local amount = enclosure_placement.placement_money_payout(state.board, row, col, owner)
			if amount <= 0 then
				return
			end
			local side = owner == config.OWNER_BLACK and "black" or "white"
			local player = require("match_state").player_for_color(state, side)
			player.resources.money = (player.resources.money or 0) + amount
		end,
	}
end

return M
