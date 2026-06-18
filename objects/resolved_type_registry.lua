--- Shared resolved effect → round scoring def mapping for resolver and AI.
--- @module objects.resolved_type_registry

local effect_enums = require("objects.effects_conditions.scheduling")

local M = {}

local ON_PLAY = effect_enums.ACTION.on_play
local PHASE_POINTS = effect_enums.PHASE.points
local PHASE_MULT = effect_enums.PHASE.mult

--- @param resolved table
--- @return table|nil
local function round_def_add_points(resolved)
	return {
		effect_name = "add_points",
		action = resolved.action or ON_PLAY,
		phase = PHASE_POINTS,
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_add_mult(resolved)
	return {
		effect_name = "add_mult",
		action = resolved.action or ON_PLAY,
		phase = PHASE_MULT,
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_add_energy(resolved)
	return {
		effect_name = "add_energy",
		action = resolved.action or ON_PLAY,
		phase = resolved.phase or PHASE_POINTS,
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_add_money(resolved)
	return {
		effect_name = "add_money",
		action = resolved.action or ON_PLAY,
		phase = PHASE_POINTS,
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_kamikaze_sacrifice(resolved)
	return {
		effect_name = "kamikaze_sacrifice",
		action = resolved.action or ON_PLAY,
		phase = PHASE_POINTS,
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_self_destruct_timed(resolved)
	return {
		effect_name = "self_destruct_timed",
		action = resolved.action or ON_PLAY,
		phase = PHASE_POINTS,
		immediate_points = resolved.immediate_points or resolved.value,
		delay_rounds = resolved.delay_rounds,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_money_field_enclosure_payout(resolved)
	return {
		effect_name = "money_field_enclosure_payout",
		action = resolved.action or ON_PLAY,
		phase = resolved.phase or PHASE_POINTS,
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_copper_threshold_plus_mult(resolved)
	return {
		effect_name = "copper_threshold_plus_mult",
		action = resolved.action or ON_PLAY,
		phase = resolved.phase or PHASE_MULT,
		value = resolved.value,
		conditions = resolved.conditions,
		priority = resolved.priority or 10,
	}
end

local function round_def_final_blow_placement(resolved)
	return {
		effect_name = "final_blow_placement",
		action = resolved.action or ON_PLAY,
		phase = PHASE_POINTS,
		priority = resolved.priority or 10,
	}
end

local function round_def_retrigger_prior_stone_effect(resolved)
	return {
		effect_name = "retrigger_prior_stone_effect",
		action = resolved.action or ON_PLAY,
		phase = PHASE_POINTS,
		priority = resolved.priority or 10,
	}
end

local function round_def_escalating_points_init(resolved)
	return {
		effect_name = "escalating_points_bank",
		action = resolved.action or ON_PLAY,
		phase = PHASE_POINTS,
		priority = resolved.priority or 10,
	}
end

M.ROUND_DEF_BY_NAME = {
	add_points = round_def_add_points,
	add_mult = round_def_add_mult,
	add_energy = round_def_add_energy,
	add_money = round_def_add_money,
	kamikaze_sacrifice = round_def_kamikaze_sacrifice,
	self_destruct_timed = round_def_self_destruct_timed,
	money_field_enclosure_payout = round_def_money_field_enclosure_payout,
	copper_threshold_plus_mult = round_def_copper_threshold_plus_mult,
	final_blow_placement = round_def_final_blow_placement,
	retrigger_prior_stone_effect = round_def_retrigger_prior_stone_effect,
	escalating_points_bank_init = round_def_escalating_points_init,
}

--- @param resolved table|nil
--- @return table|nil
function M.round_effect_def_from_resolved(resolved)
	if not resolved or not resolved.effect_name then
		return nil
	end
	local builder = M.ROUND_DEF_BY_NAME[resolved.effect_name]
	if not builder then
		return nil
	end
	return builder(resolved)
end

--- @param resolved_effects table
--- @return table
function M.round_effect_defs_from_resolved(resolved_effects)
	local round = {}
	for i = 1, #resolved_effects do
		local round_def = M.round_effect_def_from_resolved(resolved_effects[i])
		if round_def then
			round[#round + 1] = round_def
		end
	end
	return round
end

--- @param resolved table|nil
--- @return boolean
function M.is_valid_resolved(resolved)
	if not resolved or type(resolved) ~= "table" then
		return false
	end
	local name = resolved.effect_name
	if name == "add_points" or name == "add_mult" or name == "add_energy" then
		return type(resolved.value) == "number"
	end
	if name == "kamikaze_sacrifice" or name == "self_destruct_timed" then
		return type(resolved.value) == "number" or type(resolved.immediate_points) == "number"
	end
	if name == "add_money" then
		return type(resolved.value) == "table" and type(resolved.value.amount) == "number"
	end
	if name == "money_field_enclosure_payout" then
		return true
	end
	if name == "copper_threshold_plus_mult" then
		return true
	end
	if name == "final_blow_placement" or name == "retrigger_prior_stone_effect" then
		return true
	end
	if name == "escalating_points_bank_init" then
		return true
	end
	if name == "anti_capture_immunity" then
		return true
	end
	return false
end

return M
