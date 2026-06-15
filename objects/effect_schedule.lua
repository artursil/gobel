--- Parses effect ``when`` / ``phase`` scheduling with legacy ``macro`` / ``sub`` / ``lifecycle`` compat.
--- @module objects.effect_schedule

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
--- @return string|nil when
--- @return string|nil phase
function M.parse_when_phase(effect_def)
	if not effect_def then
		return nil, nil
	end
	if effect_def.when and effect_def.phase then
		return effect_def.when, effect_def.phase
	end
	if effect_def.lifecycle == "board_reconcile" then
		return "board_reconcile", effect_def.sub or effect_def.phase or "territory"
	end
	if effect_def.lifecycle == "placement" then
		return "playing_stones", effect_def.sub or effect_def.phase or "points"
	end
	if effect_def.macro == "on_removed" then
		return "on_removed", effect_def.sub or effect_def.phase or "points"
	end
	if effect_def.macro == "end_of_turn" then
		return "end_of_turn", effect_def.sub or effect_def.phase or "points"
	end
	if effect_def.macro == "board_reconcile" then
		return "board_reconcile", effect_def.sub or effect_def.phase or "territory"
	end
	if effect_def.macro then
		return effect_def.macro, effect_def.sub or effect_def.phase or "points"
	end
	local legacy = effect_def.phase
	if legacy == "distance" or legacy == "territory" then
		return "playing_stones", "territory"
	end
	if legacy == "points" then
		return effect_def._legacy_macro or "playing_stones", "points"
	end
	if legacy == "mult" then
		return effect_def._legacy_macro or "playing_stones", "mult"
	end
	return nil, nil
end

--- Maps ``when`` to legacy resolve macro name used by ``resolve_round``.
--- @param when string
--- @return string
function M.when_to_resolve_macro(when)
	if when == "playing_stones" or when == "playing_cards" then
		return when
	end
	if when == "end_of_turn" or when == "before_turn" or when == "game_start" or when == "game_end" then
		return when
	end
	if when == "board_reconcile" or when == "on_removed" or when == "tick" then
		return when
	end
	return when
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
	local when, phase = M.parse_when_phase(effect_def)
	if when ~= "playing_stones" then
		return false
	end
	if effect_def.effect_name and M.PLACEMENT_RECORD_EFFECT_NAMES[effect_def.effect_name] then
		return true
	end
	return phase == "points" or phase == "mult"
end

--- @param effect_def table|nil
--- @return boolean
function M.skips_board_scan(effect_def)
	return M.is_placement_record(effect_def)
end

--- @param effect_def table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @param is_board_territory_effect function|nil
--- @return boolean
function M.matches_resolve_pass(effect_def, active_macro, active_sub, territory_step, is_board_territory_effect)
	local when, phase = M.parse_when_phase(effect_def)
	if not when or not phase then
		return false
	end
	local macro = M.when_to_resolve_macro(when)
	if phase ~= active_sub then
		return false
	end
	local board_territory = is_board_territory_effect and is_board_territory_effect(effect_def) or false
	if active_sub == "territory" and board_territory then
		local step = effect_def.territory_step
		if territory_step and step and step ~= territory_step then
			return false
		end
		if territory_step and not step then
			return false
		end
		return true
	end
	if macro ~= active_macro then
		return false
	end
	if active_sub == "territory" and territory_step and effect_def.territory_step and effect_def.territory_step ~= territory_step then
		return false
	end
	if active_sub == "territory" and territory_step and not effect_def.territory_step then
		return false
	end
	return true
end

return M
