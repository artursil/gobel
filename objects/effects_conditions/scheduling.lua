--- Action/phase enums, schedule parsing, and resolved-effect factory.
--- @module objects.effects_conditions.scheduling

local M = {}

M.ACTION = {
	game_start = "game_start",
	before_turn = "before_turn",
	on_card = "on_card",
	on_play = "on_play",
	end_of_turn = "end_of_turn",
	tick = "tick",
	on_removed = "on_removed",
	game_end = "game_end",
}

M.PHASE = {
	territory = "territory",
	points = "points",
	mult = "mult",
}

M.PHASE_ORDER = { M.PHASE.territory, M.PHASE.points, M.PHASE.mult }

M.ACTION_ORDER = {
	M.ACTION.game_start,
	M.ACTION.before_turn,
	M.ACTION.on_card,
	M.ACTION.on_play,
	M.ACTION.end_of_turn,
	M.ACTION.on_removed,
	M.ACTION.game_end,
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
	self_destruct_setup = true,
	final_blow_placement = true,
	retrigger_prior_stone_effect = true,
	delay_reward_setup = true,
	blockade_adjacent = true,
	anti_capture_setup = true,
	capture_zero_liberty_enemy = true,
	defence_solidity_network = true,
	defence_adjacency_solidity = true,
	escalating_points_bank_init = true,
	territory_to_multiplier_snapshot = true,
}

local VALID_CANONICAL_ACTION = {}
for _, value in pairs(M.ACTION) do
	VALID_CANONICAL_ACTION[value] = true
end

local VALID_PHASE_LOOKUP = {}
for _, value in pairs(M.PHASE) do
	VALID_PHASE_LOOKUP[value] = true
end

--- Map legacy sub/phase strings to canonical scoring phase.
function M.sub_to_phase(sub_or_phase)
	if sub_or_phase == "distance" then
		return M.PHASE.territory
	end
	if VALID_PHASE_LOOKUP[sub_or_phase] then
		return sub_or_phase
	end
	return sub_or_phase
end

--- Normalize action string to a canonical ACTION value when recognized.
function M.normalize_action(action)
	if not action then
		return nil
	end
	if VALID_CANONICAL_ACTION[action] then
		return action
	end
	return nil
end

--- Whether the value is a canonical ACTION enum member.
function M.is_valid_action(action)
	return action ~= nil and VALID_CANONICAL_ACTION[action] == true
end

function M.is_valid_phase(phase)
	return phase ~= nil and VALID_PHASE_LOOKUP[phase] == true
end

--- Parse canonical action and phase from a definition row.
function M.parse_action_phase(effect_def)
	if not effect_def then
		return nil, nil
	end
	if effect_def.action and effect_def.phase then
		return M.normalize_action(effect_def.action), effect_def.phase
	end
	return nil, nil
end

function M.is_placement_record(effect_def)
	if not effect_def then
		return false
	end
	if effect_def.placement_record == true then
		return true
	end
	local action, phase = M.parse_action_phase(effect_def)
	if action ~= M.ACTION.on_play then
		return false
	end
	if effect_def.effect_name and M.PLACEMENT_RECORD_EFFECT_NAMES[effect_def.effect_name] then
		return true
	end
	return phase == M.PHASE.points or phase == M.PHASE.mult
end

function M.skips_board_scan(effect_def)
	return M.is_placement_record(effect_def)
end

--- Whether an effect definition matches the active resolve pass.
function M.matches_resolve_pass(effect_def, active_action, active_phase, territory_step, is_board_territory_effect)
	local action, phase = M.parse_action_phase(effect_def)
	if not action or not phase then
		return false
	end
	if phase ~= active_phase then
		return false
	end
	local board_territory = is_board_territory_effect and is_board_territory_effect(effect_def) or false
	if active_phase == M.PHASE.territory and board_territory then
		local step = effect_def.territory_step
		if territory_step and step and step ~= territory_step then
			return false
		end
		if territory_step and not step then
			return false
		end
		return true
	end
	if action ~= active_action then
		return false
	end
	if active_phase == M.PHASE.territory and territory_step and effect_def.territory_step and effect_def.territory_step ~= territory_step then
		return false
	end
	if active_phase == M.PHASE.territory and territory_step and not effect_def.territory_step then
		return false
	end
	return true
end

return M
