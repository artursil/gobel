--- Resolve immediate placement scoring effects from stone definitions.
--- @module single_game.resolver.placement_lifecycle

local effect_registry = require("effect_registry")
local effect_schedule = require("objects.effect_schedule")
local territory_control_rounds = require("single_game.resolver.helpers.territory_control_rounds")
local resolved_type_registry = require("single_game.resolver.resolved_type_registry")

local M = {}

local IMMEDIATE_EFFECT_NAMES = {
	add_points = true,
	add_mult = true,
	add_energy = true,
	add_money = true,
	mult_control_streak = true,
	kamikaze_sacrifice = true,
	money_field_enclosure_payout = true,
	copper_threshold_plus_mult = true,
	self_destruct_timed = true,
	final_blow_placement = true,
	retrigger_prior_stone_effect = true,
}

--- @param effect_def table
--- @return boolean
function M.is_immediate_placement_effect(effect_def)
	if effect_schedule.is_placement_record(effect_def) then
		local name = effect_def.effect_name
		if name == "wall_stone" or name == "diagonal_group_points" or name == "line_group_points" then
			return false
		end
		if name == "delay_reward_survival" or name == "blockade_adjacent" or name == "anti_capture_immunity" then
			return false
		end
		if name == "capture_zero_liberty_enemy" or name == "escalating_points_bank_init" then
			return false
		end
		if name == "territory_to_multiplier_snapshot" then
			return false
		end
		return IMMEDIATE_EFFECT_NAMES[effect_def.effect_name] == true
			or resolved_type_registry.round_effect_def_from_resolved(effect_registry.stones.resolve(effect_def)) ~= nil
	end
	return IMMEDIATE_EFFECT_NAMES[effect_def.effect_name] == true
end

--- @param effect_def table
--- @param ctx table
--- @return table|nil
local function resolve_immediate_effect(effect_def, ctx)
	if effect_def.effect_name == "mult_control_streak" then
		if ctx.row == nil or ctx.col == nil then
			return nil
		end
		local delta = territory_control_rounds.placement_plus_mult_delta(
			ctx.state,
			ctx.row,
			ctx.col,
			ctx.owner
		)
		if delta == 0 then
			return nil
		end
		return effect_registry.stones.resolve({
			effect_name = "add_mult",
			macro = effect_def.macro or "playing_stones",
			sub = effect_def.sub or "mult",
			value = delta,
			priority = effect_def.priority or 10,
		})
	end
	return effect_registry.stones.resolve(effect_def)
end

--- @param stone_def table
--- @param ctx table
--- @return table
function M.resolve_from_stone_def(stone_def, ctx)
	if type(stone_def.behavior) == "function" then
		return stone_def.behavior(ctx.state, ctx.actor)
	end
	local out = {}
	if not stone_def or not stone_def.effects then
		return out
	end
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		if effect_def.effect_name == "kamikaze_sacrifice" or M.is_immediate_placement_effect(effect_def) then
			local resolved = resolve_immediate_effect(effect_def, ctx)
			if resolved then
				out[#out + 1] = resolved
			end
		end
	end
	return out
end

--- @param resolved table|nil
--- @return boolean
function M.is_valid_resolved(resolved)
	return resolved_type_registry.is_valid_resolved(resolved)
end

--- @return string[]
function M.immediate_placement_effect_name_keys()
	local keys = {}
	for name in pairs(IMMEDIATE_EFFECT_NAMES) do
		keys[#keys + 1] = name
	end
	table.sort(keys)
	return keys
end

return M
