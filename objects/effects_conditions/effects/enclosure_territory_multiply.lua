--- Multiply territory values inside the enclosure controlled by this stone.
--- @module objects.effects_conditions.effects.enclosure_territory_multiply

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local enclosure = require("single_game.resolver.enclosure")
local targets = require("objects.effects_conditions.helpers.shared.enclosure_multiply_targets")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or stone_params.enclosure_stone_multiplier
	return {
		type = "ENCLOSURE_TERRITORY_MULTIPLY",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.territory,
		priority = effect.priority or stone_params.default_effect_priority,
		value = effect.value,
		conditions = effect.conditions or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			local row = kwargs.row
			local col = kwargs.col
			local walls = state.enclosure_walls
			if not walls then
				walls = enclosure.extract_walls(state.board)
			end
			local stone_kind = state.board[row][col].kind
			local target_keys = targets.resolve_targets(walls, state.board, owner, row, col, stone_kind)
			target_keys = targets.filter_by_region_owner(target_keys, state, owner, state.board, stone_kind)
			if not next(target_keys) then
				return
			end
			state.territory_value = state.territory_value or {}
			for key in pairs(target_keys) do
				local tr = math.floor(key / 100)
				local tc = key % 100
				state.territory_value[tr] = state.territory_value[tr] or {}
				local cur = state.territory_value[tr][tc] or 1
				state.territory_value[tr][tc] = cur * value
			end
		end,
	}
end

return M
