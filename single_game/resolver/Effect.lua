--- Effect schema runtime implementation conforming to single_game/resolver/Effect.schema.md
--- @module single_game.resolver.Effect

local M = {}

--- @param effect_def table
--- @return table
function M.new(effect_def)
	return {
		effect_name = effect_def.effect_name,
		macro = effect_def.macro,
		sub = effect_def.sub,
		phase = effect_def.sub or effect_def.phase,
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
	if effect_def.macro and effect_def.sub then
		return true
	end
	if effect_def.phase and type(effect_def.phase) == "string" then
		return true
	end
	return false, "Missing macro/sub or legacy phase"
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
--- @param current_phase string active sub phase name
--- @return boolean
function M.applies_to_phase(effect, current_phase)
	return (effect.sub or effect.phase) == current_phase
end

--- @param effect table
--- @return number
function M.get_priority(effect)
	return effect.priority or 10
end

return M
