--- Card effect: heal solidity on the selected board stone from resolution metadata.
---
--- Runs on ``on_card`` in the ``points`` phase. No def-row conditions; target validation
--- is authoritative in ``validate_card_targets``. Reads the stone cell via ``selected_stone``.
---
--- Definition fields: ``value.amount`` (defaults to ``card_params.card_heal_1_amount``).
---
--- Shared helpers: ``selected_stone``, ``stone_combat``.
---
--- No-op: missing selected stone cell.
--- @module objects.effects_conditions.effects.heal_selected_stone

local card_params = require("objects.parameters.cards")
local scheduling = require("objects.effects_conditions.scheduling")
local selected_stone = require("objects.effects_conditions.helpers.shared.selected_stone")
local stone_combat = require("objects.effects_conditions.helpers.shared.stone_combat")

local M = {}

--- Build resolved heal-selected-stone effect with inline apply.
--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or {}
	local amount = value.amount or card_params.card_heal_1_amount
	return {
		type = "HEAL_SELECTED_STONE",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_card,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or 10,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, _owner, _kwargs)
			local _, _, cell = selected_stone.selected_stone_cell(state)
			if not cell then
				return
			end
			stone_combat.apply_heal_to_cell(cell, amount)
		end,
	}
end

return M
