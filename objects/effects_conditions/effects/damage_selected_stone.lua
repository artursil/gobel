--- Card effect: deal damage to the selected board stone from resolution metadata.
---
--- Runs on ``on_card`` in the ``points`` phase. No def-row conditions; target validation
--- is authoritative in ``validate_card_targets``. Reads row/col via ``selected_stone`` shared
--- helper from ``state.resolution``.
---
--- Definition fields: ``value.amount`` (defaults to ``card_params.card_attack_1_damage``).
---
--- Lethal damage sets cell solidity to 0 and enqueues on ``pending_stone_removals``; the
--- remove-stones stage drains after the card removal beat (stone stays visible until then).
---
--- Shared helpers: ``selected_stone``, ``stone_combat``.
---
--- No-op: missing or empty selected stone cell.
--- @module objects.effects_conditions.effects.damage_selected_stone

local card_params = require("objects.parameters.cards")
local scheduling = require("objects.effects_conditions.scheduling")
local selected_stone = require("objects.effects_conditions.helpers.shared.selected_stone")
local stone_combat = require("objects.effects_conditions.helpers.shared.stone_combat")

local M = {}

--- Build resolved damage-selected-stone effect with inline apply.
--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or {}
	local amount = value.amount or card_params.card_attack_1_damage
	return {
		type = "DAMAGE_SELECTED_STONE",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_card,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or 10,
		value = value,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local row, col, cell = selected_stone.selected_stone_cell(state)
			if not cell then
				return
			end
			stone_combat.apply_damage_to_cell(state, owner, row, col, cell, amount, "card_damage")
		end,
	}
end

return M
