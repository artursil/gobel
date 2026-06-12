--- Shared resolved effect type → round scoring def mapping for resolver and AI.
--- @module single_game.resolver.resolved_type_registry

local M = {}

--- @param resolved table
--- @return table|nil
local function round_def_add_points(resolved)
	return {
		effect_name = "add_points",
		macro = "playing_stones",
		sub = "points",
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_add_mult(resolved)
	return {
		effect_name = "add_mult",
		macro = "playing_stones",
		sub = "mult",
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_add_energy(resolved)
	return {
		effect_name = "add_energy",
		macro = resolved.macro or "playing_stones",
		sub = resolved.sub or "points",
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_add_money(resolved)
	return {
		effect_name = "add_money",
		macro = "playing_stones",
		sub = "points",
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_kamikaze_sacrifice(resolved)
	return {
		effect_name = "kamikaze_sacrifice",
		macro = "playing_stones",
		sub = "points",
		value = resolved.value,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_self_destruct_timed(resolved)
	return {
		effect_name = "self_destruct_timed",
		macro = "playing_stones",
		sub = "points",
		immediate_points = resolved.value,
		delay_rounds = resolved.delay_rounds,
		priority = resolved.priority or 10,
	}
end

--- @param resolved table
--- @return table|nil
local function round_def_money_field_enclosure_payout(resolved)
	local def = resolved._effect_def or {}
	return {
		effect_name = "money_field_enclosure_payout",
		macro = def.macro or "playing_stones",
		sub = def.sub or "points",
		value = def.value,
		priority = resolved.priority or def.priority or 10,
	}
end

M.ROUND_DEF_BY_TYPE = {
	ADD_POINTS = round_def_add_points,
	ADD_MULT = round_def_add_mult,
	ADD_ENERGY = round_def_add_energy,
	ADD_MONEY = round_def_add_money,
	KAMIKAZE_SACRIFICE = round_def_kamikaze_sacrifice,
	SELF_DESTRUCT_TIMED = round_def_self_destruct_timed,
	MONEY_FIELD_ENCLOSURE_PAYOUT = round_def_money_field_enclosure_payout,
}

--- @param resolved table|nil
--- @return table|nil
function M.round_effect_def_from_resolved(resolved)
	if not resolved or not resolved.type then
		return nil
	end
	local builder = M.ROUND_DEF_BY_TYPE[resolved.type]
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
	if resolved.type == "ADD_POINTS" or resolved.type == "ADD_MULT" or resolved.type == "ADD_ENERGY" then
		return type(resolved.value) == "number"
	end
	if resolved.type == "KAMIKAZE_SACRIFICE" or resolved.type == "SELF_DESTRUCT_TIMED" then
		return type(resolved.value) == "number"
	end
	if resolved.type == "ADD_MONEY" then
		return type(resolved.value) == "table" and type(resolved.value.amount) == "number"
	end
	if resolved.type == "MONEY_FIELD_ENCLOSURE_PAYOUT" then
		return true
	end
	if resolved.type == "ANTI_CAPTURE_IMMUNITY" then
		return true
	end
	return false
end

return M
