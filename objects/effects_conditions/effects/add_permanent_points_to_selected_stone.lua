--- Card effect: permanently add per-cell points bonus to selected friendly stone.
---
--- Runs on ``on_card`` in the ``points`` phase. Gate conditions on the def row:
--- ``selected_target_exists``, ``selected_target_is_friendly_stone``. Target is read from
--- resolution via ``selected_stone`` — not condition kwargs.
---
--- Definition fields: ``value.points`` (defaults to ``card_params.forge_mark_points_default``).
---
--- Mutates ``state.board_stone_modifiers[row:col].points_bonus``.
---
--- Shared helpers: ``selected_stone``.
---
--- No-op: missing or empty selected stone cell.
--- @module objects.effects_conditions.effects.add_permanent_points_to_selected_stone

local card_params = require("objects.parameters.cards")
local scheduling = require("objects.effects_conditions.scheduling")
local selected_stone = require("objects.effects_conditions.helpers.shared.selected_stone")

local M = {}

--- Build resolved forge-mark effect with inline apply.
--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or {}
	local points = value.points or card_params.forge_mark_points_default
	return {
		type = "ADD_PERMANENT_POINTS_TO_SELECTED_STONE",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_card,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or 10,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, _owner, _kwargs)
			local row, col, cell = selected_stone.selected_stone_cell(state)
			if not cell then
				return
			end
			state.board_stone_modifiers = state.board_stone_modifiers or {}
			local key = row .. ":" .. col
			state.board_stone_modifiers[key] = state.board_stone_modifiers[key] or { points_bonus = 0 }
			state.board_stone_modifiers[key].points_bonus = state.board_stone_modifiers[key].points_bonus + points
		end,
	}
end

return M
