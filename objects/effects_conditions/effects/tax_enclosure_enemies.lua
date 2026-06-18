--- End-of-turn enclosure tax payout for enemy stones inside wall region.
--- @module objects.effects_conditions.effects.tax_enclosure_enemies

local config = require("config")
local enclosure = require("single_game.resolver.enclosure")
local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or {}
	return {
		type = "TAX_ENCLOSURE_ENEMIES",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.end_of_turn,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			local active_owner = helpers.active_end_of_turn_owner(state)
			if not active_owner or owner ~= active_owner then
				return
			end
			local wall = enclosure.innermost_wall_containing(state.board, kwargs.row, kwargs.col, owner)
			if not wall then
				return
			end
			local region_key = enclosure.wall_region_key(wall)
			state._tax_enclosure_paid = state._tax_enclosure_paid or {}
			if state._tax_enclosure_paid[region_key] then
				return
			end
			state._tax_enclosure_paid[region_key] = true
			local enemy_count = enclosure.count_enemy_stones_in_wall(state.board, wall, owner)
			if enemy_count <= 0 then
				return
			end
			local money_per = value.money_per_enemy or stone_params.tax_money_per_enemy
			local points_per = value.points_per_enemy or stone_params.tax_points_per_enemy
			local side = owner == config.OWNER_BLACK and "black" or "white"
			local player = require("match_state").player_for_color(state, side)
			player.resources.money = (player.resources.money or 0) + enemy_count * money_per
			state.scores.points[owner] = state.scores.points[owner] + enemy_count * points_per
		end,
	}
end

return M
