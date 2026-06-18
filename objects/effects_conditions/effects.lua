--- Thin effect dispatch registry.
--- @module objects.effects_conditions.effects

local board = require("board")
local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local duration_left = require("objects.effects_conditions.helpers.shared.duration_left")

local M = {}

local EFFECT_MODULES = {
	add_points = require("objects.effects_conditions.effects.add_points"),
	add_energy = require("objects.effects_conditions.effects.add_energy"),
	kamikaze_sacrifice = require("objects.effects_conditions.effects.kamikaze_sacrifice"),
	add_mult = require("objects.effects_conditions.effects.add_mult"),
	distance_bonus = require("objects.effects_conditions.effects.distance_bonus"),
	count_and_multiply_x_mult = require("objects.effects_conditions.effects.count_and_multiply_x_mult"),
	create_temporary_stance = require("objects.effects_conditions.effects.create_temporary_stance"),
	copy_right_effect = require("objects.effects_conditions.effects.copy_right_effect"),
	adjust_run_persistent_counter = require("objects.effects_conditions.effects.adjust_run_persistent_counter"),
	apply_run_persistent_pending_delta_as_mult = require("objects.effects_conditions.effects.apply_run_persistent_pending_delta_as_mult"),
	apply_run_persistent_counter_as_mult = require("objects.effects_conditions.effects.apply_run_persistent_counter_as_mult"),
	add_money = require("objects.effects_conditions.effects.add_money"),
	escalating_money_tracker = require("objects.effects_conditions.effects.escalating_money_tracker"),
	escalating_money_capture_penalty = require("objects.effects_conditions.effects.escalating_money_capture_penalty"),
	money_field_enclosure_payout = require("objects.effects_conditions.effects.money_field_enclosure_payout"),
	pattern_x_mult = require("objects.effects_conditions.effects.pattern_x_mult"),
	pattern_plus_mult = require("objects.effects_conditions.effects.pattern_plus_mult"),
	diagonal_group_points = require("objects.effects_conditions.effects.diagonal_group_points"),
	defence_solidity_network = require("objects.effects_conditions.effects.defence_solidity_network"),
	defence_adjacency_solidity = require("objects.effects_conditions.effects.defence_adjacency_solidity"),
	capture_zero_liberty_enemy = require("objects.effects_conditions.effects.capture_zero_liberty_enemy"),
	blockade_adjacent = require("objects.effects_conditions.effects.blockade_adjacent"),
	blockade_tick = require("objects.effects_conditions.effects.blockade_tick"),
	tax_enclosure_enemies = require("objects.effects_conditions.effects.tax_enclosure_enemies"),
	territory_to_points = require("objects.effects_conditions.effects.territory_to_points"),
	line_group_points = require("objects.effects_conditions.effects.line_group_points"),
	copper_threshold_plus_mult = require("objects.effects_conditions.effects.copper_threshold_plus_mult"),
	mult_control_streak = require("objects.effects_conditions.effects.mult_control_streak"),
	control_territory_override = require("objects.effects_conditions.effects.control_territory_override"),
	enclosure_territory_multiply = require("objects.effects_conditions.effects.enclosure_territory_multiply"),
	territory_to_multiplier_snapshot = require("objects.effects_conditions.effects.territory_to_multiplier_snapshot"),
	territory_to_multiplier = require("objects.effects_conditions.effects.territory_to_multiplier"),
	escalating_points_bank_init = require("objects.effects_conditions.effects.escalating_points_bank_init"),
	escalating_points_bank = require("objects.effects_conditions.effects.escalating_points_bank"),
	escalating_points_capture_transfer = require("objects.effects_conditions.effects.escalating_points_capture_transfer"),
	final_blow_placement = require("objects.effects_conditions.effects.final_blow_placement"),
	retrigger_prior_stone_effect = require("objects.effects_conditions.effects.retrigger_prior_stone_effect"),
	double_corner_nearby_territory = require("objects.effects_conditions.effects.double_corner_nearby_territory"),
	wall_stone = require("objects.effects_conditions.effects.wall_stone"),
	destroy_selected_enemy_stone = require("objects.effects_conditions.effects.destroy_selected_enemy_stone"),
	add_permanent_points_to_selected_stone = require("objects.effects_conditions.effects.add_permanent_points_to_selected_stone"),
	damage_selected_stone = require("objects.effects_conditions.effects.damage_selected_stone"),
	heal_selected_stone = require("objects.effects_conditions.effects.heal_selected_stone"),
	delay_reward_setup = require("objects.effects_conditions.effects.delay_reward_setup"),
	delay_reward_payout = require("objects.effects_conditions.effects.delay_reward_payout"),
	anti_capture_setup = require("objects.effects_conditions.effects.anti_capture_setup"),
	anti_capture_expire = require("objects.effects_conditions.effects.anti_capture_expire"),
	self_destruct_setup = require("objects.effects_conditions.effects.self_destruct_setup"),
	self_destruct_expire = require("objects.effects_conditions.effects.self_destruct_expire"),
}

for effect_name, mod in pairs(EFFECT_MODULES) do
	M[effect_name] = function(effect)
		return mod.build(effect)
	end
end

local BOARD_COORD_EFFECT_NAMES = {
	control_territory_override = true,
	territory_to_points = true,
	territory_to_multiplier = true,
	territory_to_multiplier_snapshot = true,
	tax_enclosure_enemies = true,
	escalating_points_bank = true,
	escalating_points_bank_init = true,
	escalating_money_tracker = true,
}

local BOARD_SCAN_ONLY = {
	distance_bonus = true,
	enclosure_territory_multiply = true,
	double_corner_nearby_territory = true,
}

local function merge_kwargs(kwargs, defaults)
	local merged = {}
	for key, value in pairs(kwargs or {}) do
		merged[key] = value
	end
	for key, value in pairs(defaults or {}) do
		merged[key] = value
	end
	return merged
end

function M.resolve(effect_def)
	if not effect_def or not effect_def.effect_name then
		return nil
	end
	if BOARD_SCAN_ONLY[effect_def.effect_name] then
		if effect_def.effect_name == "enclosure_territory_multiply"
			or effect_def.effect_name == "double_corner_nearby_territory" then
			return nil
		end
	end
	local builder = M[effect_def.effect_name]
	if not builder then
		return nil
	end
	local resolved = builder(effect_def)
	if resolved then
		resolved._effect_def = effect_def
	end
	return resolved
end

function M.resolve_at_board(row, col, effect_def)
	if not effect_def or not effect_def.effect_name then
		return nil
	end
	if effect_def.effect_name == "enclosure_territory_multiply" then
		return EFFECT_MODULES.enclosure_territory_multiply.build_at_board(row, col, effect_def)
	end
	if effect_def.effect_name == "double_corner_nearby_territory" then
		return EFFECT_MODULES.double_corner_nearby_territory.build_at_board(row, col, effect_def)
	end
	local builder = M[effect_def.effect_name]
	if not builder then
		return nil
	end
	return builder(effect_def)
end

function M.wrap_board_scan(resolved, owner, row, col, stone_cell, action)
	if not resolved or not resolved.apply then
		return resolved
	end
	local base_apply = resolved.apply
	local needs_coords = BOARD_COORD_EFFECT_NAMES[resolved.effect_name]
	local needs_tick_context = action == scheduling.ACTION.tick
	resolved.apply = function(state, effect_owner, kwargs)
		local merged = kwargs or {}
		if needs_coords or needs_tick_context then
			merged = merge_kwargs(merged, { row = row, col = col })
		end
		if needs_tick_context and stone_cell then
			merged = merge_kwargs(merged, { cell = stone_cell })
		end
		base_apply(state, effect_owner or owner, merged)
	end
	return resolved
end

function M.resolve_board_stone(stone_cell, row, col, state, active_action, active_phase, territory_step)
	local scoring_phases = require("single_game.resolver.scoring_phases")
	local content = require("content")
	local stone_ref = stone_cell.level and { def_id = stone_cell.kind, level = stone_cell.level } or stone_cell.kind
	local stone_def = content.resolve_stone(stone_ref)
	local key = helpers.stone_key(row, col)
	local n = config.BOARD_SIZE
	local out = {}
	local effect_defs = {}
	local owner = stone_cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
	local action = scheduling.normalize_action(active_action or state._resolve_action) or scheduling.ACTION.on_play

	if action == scheduling.ACTION.tick and not duration_left.has_timer(stone_cell) then
		return out
	end

	if stone_def and stone_def.effects then
		for i = 1, #stone_def.effects do
			effect_defs[#effect_defs + 1] = stone_def.effects[i]
		end
	end

	for _, effect_def in ipairs(effect_defs) do
		if scoring_phases.skips_board_scan(effect_def) then
		elseif not scoring_phases.matches(effect_def, action, active_phase, territory_step) then
		elseif effect_def.effect_name == "distance_bonus" then
			local resolved = M.resolve(effect_def)
			if resolved then
				resolved.action = action
				resolved.phase = active_phase
				resolved.apply = function(current_state, _effect_owner, _kwargs)
					helpers.apply_distance_bonus_for_stone(stone_def, current_state, key, n, effect_def.value)
				end
				out[#out + 1] = resolved
			end
		elseif effect_def.effect_name == "enclosure_territory_multiply"
			or effect_def.effect_name == "double_corner_nearby_territory" then
			local resolved = M.resolve_at_board(row, col, effect_def)
			if resolved then
				resolved.action = action
				resolved.phase = active_phase
				out[#out + 1] = M.wrap_board_scan(resolved, owner, row, col, stone_cell, action)
			end
		else
			local resolved = M.resolve(effect_def)
			if resolved and resolved.apply then
				resolved.action = action
				resolved.phase = active_phase
				out[#out + 1] = M.wrap_board_scan(resolved, owner, row, col, stone_cell, action)
			end
		end
	end

	return out
end

function M.apply_on_removed_effects(state, row, col, cell, opts)
	if board.is_empty(cell) then
		return
	end
	local content = require("content")
	local stone_ref = cell.level and { def_id = cell.kind, level = cell.level } or cell.kind
	local stone_def = content.resolve_stone(stone_ref)
	if not stone_def or not stone_def.effects then
		return
	end
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		local removal_action = effect_def.action or effect_def.when
		if removal_action == nil and effect_def.macro == "on_removed" then
			removal_action = scheduling.ACTION.on_removed
		end
		if removal_action == scheduling.ACTION.on_removed or removal_action == "on_removed" then
			local resolved = M.resolve(effect_def)
			if resolved and resolved.apply then
				resolved.apply(state, nil, { row = row, col = col, cell = cell, opts = opts })
			end
		end
	end
end

function M.resolve_stance_definition_effects(stance_type)
	local defs = require("objects.definitions.stances")
	local stance_def = defs[stance_type]
	local list = stance_def and stance_def.effects or {}
	local out = {}
	for i = 1, #list do
		local resolved = M.resolve(list[i])
		if resolved then
			out[#out + 1] = resolved
		end
	end
	return out
end

function M.resolve_card_effects(card)
	local defs = require("objects.definitions.cards")
	local card_def = defs[card.type]
	if not card_def or not card_def.effects then
		return {}
	end
	local out = {}
	for i = 1, #card_def.effects do
		local resolved = M.resolve(card_def.effects[i])
		if resolved then
			out[#out + 1] = resolved
		end
	end
	return out
end

return M
