--- Parses effect ``action`` / ``phase`` scheduling with legacy ``macro`` / ``sub`` / ``when`` / ``lifecycle`` compat.
--- @module objects.effect_schedule

local effect_enums = require("objects.effect_enums")

local M = {}

M.VALID_WHEN = {
	game_start = true,
	before_turn = true,
	playing_cards = true,
	playing_stones = true,
	board_reconcile = true,
	end_of_turn = true,
	on_removed = true,
	game_end = true,
	tick = true,
	on_card = true,
	on_play = true,
}

M.VALID_PHASE = {
	territory = true,
	points = true,
	mult = true,
}

M.PLACEMENT_RECORD_EFFECT_NAMES = {
	add_points = true,
	add_mult = true,
	add_energy = true,
	add_money = true,
	kamikaze_sacrifice = true,
	wall_stone = true,
	diagonal_group_points = true,
	line_group_points = true,
	mult_control_streak = true,
	money_field_enclosure_payout = true,
	copper_threshold_plus_mult = true,
	self_destruct_timed = true,
	final_blow_placement = true,
	retrigger_prior_stone_effect = true,
	delay_reward_survival = true,
	blockade_adjacent = true,
	anti_capture_immunity = true,
	capture_zero_liberty_enemy = true,
	escalating_points_bank_init = true,
	territory_to_multiplier_snapshot = true,
}

--- @param effect_def table|nil
--- @return string|nil action canonical or legacy-only action name
--- @return string|nil phase
function M.parse_action_phase(effect_def)
	if not effect_def then
		return nil, nil
	end
	if effect_def.action and effect_def.phase then
		return effect_enums.normalize_action(effect_def.action), effect_def.phase
	end
	if effect_def.when and effect_def.phase then
		return effect_enums.when_to_action(effect_def.when), effect_def.phase
	end
	if effect_def.lifecycle == "board_reconcile" then
		return "board_reconcile", effect_enums.sub_to_phase(effect_def.sub or effect_def.phase) or "territory"
	end
	if effect_def.lifecycle == "placement" then
		return effect_enums.ACTION.on_play, effect_enums.sub_to_phase(effect_def.sub or effect_def.phase) or "points"
	end
	if effect_def.macro == "on_removed" then
		return effect_enums.ACTION.on_removed, effect_enums.sub_to_phase(effect_def.sub or effect_def.phase) or "points"
	end
	if effect_def.macro == "end_of_turn" then
		return effect_enums.ACTION.end_of_turn, effect_enums.sub_to_phase(effect_def.sub or effect_def.phase) or "points"
	end
	if effect_def.macro == "board_reconcile" then
		return "board_reconcile", effect_enums.sub_to_phase(effect_def.sub or effect_def.phase) or "territory"
	end
	if effect_def.macro then
		return effect_enums.macro_to_action(effect_def.macro), effect_enums.sub_to_phase(effect_def.sub or effect_def.phase) or "points"
	end
	local legacy = effect_def.phase
	if legacy == "distance" or legacy == "territory" then
		return effect_enums.ACTION.on_play, effect_enums.PHASE.territory
	end
	if legacy == "points" then
		return effect_enums.normalize_action(effect_def._legacy_macro or effect_def._legacy_action) or effect_enums.ACTION.on_play,
			effect_enums.PHASE.points
	end
	if legacy == "mult" then
		return effect_enums.normalize_action(effect_def._legacy_macro or effect_def._legacy_action) or effect_enums.ACTION.on_play,
			effect_enums.PHASE.mult
	end
	return nil, nil
end

--- @param effect_def table|nil
--- @return string|nil when legacy alias for action
--- @return string|nil phase
function M.parse_when_phase(effect_def)
	local action, phase = M.parse_action_phase(effect_def)
	if not action then
		return nil, nil
	end
	if action == effect_enums.ACTION.on_play then
		return "playing_stones", phase
	end
	if action == effect_enums.ACTION.on_card then
		return "playing_cards", phase
	end
	return action, phase
end

--- Maps canonical action to legacy resolve macro name used by ``resolve_round`` callers.
--- @param action string
--- @return string
function M.action_to_resolve_macro(action)
	return effect_enums.action_to_resolve_macro(action)
end

--- @param when string
--- @return string
function M.when_to_resolve_macro(when)
	return M.action_to_resolve_macro(effect_enums.when_to_action(when) or when)
end

--- @param effect_def table|nil
--- @return boolean
function M.is_placement_record(effect_def)
	if not effect_def then
		return false
	end
	if effect_def.placement_record == true then
		return true
	end
	if effect_def.lifecycle == "placement" then
		return true
	end
	local action, phase = M.parse_action_phase(effect_def)
	if action ~= effect_enums.ACTION.on_play then
		return false
	end
	if effect_def.effect_name and M.PLACEMENT_RECORD_EFFECT_NAMES[effect_def.effect_name] then
		return true
	end
	return phase == effect_enums.PHASE.points or phase == effect_enums.PHASE.mult
end

--- @param effect_def table|nil
--- @return boolean
function M.skips_board_scan(effect_def)
	return M.is_placement_record(effect_def)
end

--- @param effect_def table
--- @param active_action string canonical or legacy resolve macro
--- @param active_phase string
--- @param territory_step string|nil
--- @param is_board_territory_effect function|nil
--- @return boolean
function M.matches_resolve_pass(effect_def, active_action, active_phase, territory_step, is_board_territory_effect)
	local action, phase = M.parse_action_phase(effect_def)
	if not action or not phase then
		return false
	end
	local normalized_active = effect_enums.resolve_macro_to_action(active_action)
	if phase ~= active_phase then
		return false
	end
	local board_territory = is_board_territory_effect and is_board_territory_effect(effect_def) or false
	if active_phase == effect_enums.PHASE.territory and board_territory then
		local step = effect_def.territory_step
		if territory_step and step and step ~= territory_step then
			return false
		end
		if territory_step and not step then
			return false
		end
		return true
	end
	if action ~= normalized_active then
		return false
	end
	if active_phase == effect_enums.PHASE.territory and territory_step and effect_def.territory_step and effect_def.territory_step ~= territory_step then
		return false
	end
	if active_phase == effect_enums.PHASE.territory and territory_step and not effect_def.territory_step then
		return false
	end
	return true
end

return M
