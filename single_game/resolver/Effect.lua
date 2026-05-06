--- Effect schema runtime implementation conforming to single_game/resolver/Effect.schema.md
--- Unified effect handling for stones/cards/stances
--- @module single_game.resolver.Effect

local M = {}

--- Create an effect instance from definition.
--- @param effect_def table: {effect_name, phase, priority, value, params, duration, scope, probability, conditions, target, tags}
--- @return table: Effect instance with all schema fields
function M.new(effect_def)
	return {
		effect_name = effect_def.effect_name,
		phase = effect_def.phase,
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

--- Validate effect definition.
--- @param effect_def table
--- @return boolean: true if valid
--- @return string|nil: error message
function M.validate(effect_def)
	if not effect_def.effect_name or type(effect_def.effect_name) ~= "string" then
		return false, "Missing or non-string effect_name"
	end
	if not effect_def.phase or type(effect_def.phase) ~= "string" then
		return false, "Missing or non-string phase"
	end
	if effect_def.priority and type(effect_def.priority) ~= "number" then
		return false, "Non-numeric priority"
	end
	return true
end

--- Get effective value (including scope multiplier).
--- @param effect table
--- @param scope_multiplier number|nil: Multiplier for scope
--- @return number: Effective value
function M.get_value(effect, scope_multiplier)
	if not effect.value then
		return 0
	end
	scope_multiplier = scope_multiplier or 1.0
	return effect.value * scope_multiplier
end

--- Check if effect applies in a given phase.
--- @param effect table
--- @param current_phase string
--- @return boolean
function M.applies_to_phase(effect, current_phase)
	return effect.phase == current_phase
end

--- Get priority for sorting.
--- @param effect table
--- @return number
function M.get_priority(effect)
	return effect.priority or 10
end

return M
