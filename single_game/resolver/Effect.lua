--- Effect schema runtime implementation conforming to single_game/resolver/Effect.schema.md
--- @module single_game.resolver.Effect

local effect_enums = require("objects.effect_enums")
local effect_schedule = require("objects.effect_schedule")

local M = {}

--- @param effect_def table
--- @return table
function M.new(effect_def)
	local action, phase = effect_schedule.parse_action_phase(effect_def)
	if not action and effect_def.macro then
		action = effect_enums.macro_to_action(effect_def.macro)
	end
	if not phase then
		phase = effect_enums.sub_to_phase(effect_def.sub or effect_def.phase)
	end
	local resolve_macro = action and effect_schedule.action_to_resolve_macro(action) or effect_def.macro
	return {
		effect_name = effect_def.effect_name,
		action = action,
		phase = phase,
		macro = resolve_macro or effect_def.macro,
		sub = phase or effect_def.sub,
		priority = effect_def.priority or 10,
		value = effect_def.value,
		params = effect_def.params or {},
		duration = effect_def.duration,
		scope = effect_def.scope or "game",
		probability = effect_def.probability,
		conditions = effect_def.conditions or {},
		target = effect_def.target or {
			selector = "self",
			filters = {},
		},
		tags = effect_def.tags or {},
	}
end

--- @param effect_def table
--- @return boolean
--- @return string|nil
function M.validate(effect_def)
	if not effect_def.effect_name or type(effect_def.effect_name) ~= "string" then
		return false, "Missing or non-string effect_name"
	end
	if effect_def.action and effect_def.phase then
		return true
	end
	if effect_def.macro and effect_def.sub then
		return true
	end
	if effect_def.when and effect_def.phase then
		return true
	end
	if effect_def.phase and type(effect_def.phase) == "string" then
		return true
	end
	return false, "Missing action/phase or legacy scheduling fields"
end

--- @param effect table
--- @param scope_multiplier number|nil
--- @return number
function M.get_value(effect, scope_multiplier)
	if not effect.value then
		return 0
	end
	scope_multiplier = scope_multiplier or 1.0
	return effect.value * scope_multiplier
end

--- @param effect table
--- @param current_phase string active phase name
--- @return boolean
function M.applies_to_phase(effect, current_phase)
	return (effect.phase or effect.sub) == current_phase
end

--- @param effect table
--- @return number
function M.get_priority(effect)
	return effect.priority or 10
end

return M
