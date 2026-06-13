--- Generic placement lifecycle: resolve stone def effects and invoke commit hooks.
--- @module single_game.resolver.placement_lifecycle

local effect_registry = require("effect_registry")
local rules = require("rules")
local territory_control_rounds = require("single_game.resolver.territory_control_rounds")
local resolved_type_registry = require("single_game.resolver.resolved_type_registry")

local M = {}

local PLACEMENT_RESOLVE_EFFECT_NAMES = {
	add_points = true,
	add_mult = true,
	add_energy = true,
	add_money = true,
	mult_control_streak = true,
	money_field_enclosure_payout = true,
	copper_threshold_plus_mult = true,
	self_destruct_timed = true,
	final_blow_placement = true,
	retrigger_prior_stone_effect = true,
}

--- @param effect_def table
--- @return boolean
function M.is_placement_effect(effect_def)
	if effect_def.lifecycle == "placement" then
		return false
	end
	return PLACEMENT_RESOLVE_EFFECT_NAMES[effect_def.effect_name] == true
end

--- @param effect_def table
--- @param ctx table
--- @return table|nil
local function resolve_placement_effect(effect_def, ctx)
	if effect_def.effect_name == "mult_control_streak" then
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
	if not stone_def.effects then
		return out
	end
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		if effect_def.effect_name == "kamikaze_sacrifice" then
			if ctx.kamikaze_sacrifice_ctx and rules.kamikaze_sacrifice_triggers(ctx.kamikaze_sacrifice_ctx) then
				local resolved = resolve_placement_effect(effect_def, ctx)
				if resolved then
					out[#out + 1] = resolved
				end
			end
		elseif M.is_placement_effect(effect_def) then
			local resolved = resolve_placement_effect(effect_def, ctx)
			if resolved then
				out[#out + 1] = resolved
			end
		elseif effect_def.effect_name == "escalating_points_bank" and (effect_def.macro or "playing_stones") == "playing_stones" then
			local resolved = effect_registry.stones.resolve(effect_def)
			if resolved then
				out[#out + 1] = resolved
			end
		end
	end
	return out
end

--- @param resolved_effects table
--- @param ctx table
--- @return nil
function M.run_commit_hooks(resolved_effects, ctx)
	for i = 1, #resolved_effects do
		local resolved = resolved_effects[i]
		if resolved.on_placement then
			resolved.on_placement(ctx)
		end
	end
end

--- @param stone_def table
--- @param ctx table
--- @return table resolved_effects
--- @return table round_effect_defs
function M.compile(stone_def, ctx)
	local resolved_effects = M.resolve_from_stone_def(stone_def, ctx)
	M.run_commit_hooks(resolved_effects, ctx)
	local round_effect_defs = resolved_type_registry.round_effect_defs_from_resolved(resolved_effects)
	return resolved_effects, round_effect_defs
end

--- @param resolved table|nil
--- @return boolean
function M.is_valid_resolved(resolved)
	return resolved_type_registry.is_valid_resolved(resolved)
end

return M
