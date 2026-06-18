--- Card effect: destroy selected enemy stone with deterministic RNG chance.
---
--- Runs on ``on_card`` in the ``points`` phase. Gate conditions on the def row:
--- ``selected_target_exists``, ``selected_target_is_enemy_stone``. Target coordinates
--- are read from resolution via ``selected_stone`` — not condition kwargs.
---
--- Definition fields: ``value.chance_numerator``, ``value.chance_denominator`` (card params
--- defaults when absent).
---
--- On successful roll, enqueues removal on ``pending_stone_removals``; drain runs in the
--- card removal beat after scoring (no direct board clear in apply).
---
--- Shared helpers: ``selected_stone``, ``stone_combat``.
---
--- No-op: missing target, empty cell, failed RNG roll, invalid denominator.
--- @module objects.effects_conditions.effects.destroy_selected_enemy_stone

local card_params = require("objects.parameters.cards")
local match_state = require("match_state")
local scheduling = require("objects.effects_conditions.scheduling")
local selected_stone = require("objects.effects_conditions.helpers.shared.selected_stone")
local stone_combat = require("objects.effects_conditions.helpers.shared.stone_combat")

local M = {}

--- Build resolved destroy-selected-enemy-stone effect with inline apply.
--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local value = effect.value or {}
	local chance_numerator = value.chance_numerator or card_params.destroy_chance_numerator_default
	local chance_denominator = value.chance_denominator or card_params.destroy_chance_denominator_default
	return {
		type = "DESTROY_SELECTED_ENEMY_STONE",
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
			if chance_denominator <= 0 then
				return
			end
			local roll = match_state.rng_next_int(state, chance_denominator)
			if roll > chance_numerator then
				return
			end
			stone_combat.enqueue_removal(state, owner, row, col, "card_destroy")
		end,
	}
end

return M
