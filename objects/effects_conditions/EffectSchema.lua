--- Effect definition schema: validation and normalized runtime instances.
--- @module objects.effects_conditions.EffectSchema

local scheduling = require("objects.effects_conditions.scheduling")
local ConditionSchema = require("objects.effects_conditions.ConditionSchema")

local M = {}

M.ACTION = scheduling.ACTION
M.PHASE = scheduling.PHASE
M.PHASE_ORDER = scheduling.PHASE_ORDER
M.ACTION_ORDER = scheduling.ACTION_ORDER
M.schedule = scheduling

local VALID_ACTION = {}
for _, action in pairs(scheduling.ACTION) do
	VALID_ACTION[action] = true
end

local VALID_PHASES = {
	territory = true,
	points = true,
	mult = true,
}

M.VALID_ACTION = VALID_ACTION
M.VALID_PHASES = VALID_PHASES

local function list_valid(tbl)
	local result = {}
	for key in pairs(tbl) do
		table.insert(result, key)
	end
	table.sort(result)
	return table.concat(result, ", ")
end

--- Build a normalized effect instance from a definition row.
function M.new(effect_def)
	local action, phase = scheduling.parse_action_phase(effect_def)
	return {
		effect_name = effect_def.effect_name,
		action = action,
		phase = phase,
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

--- Validate an effect definition row.
function M.validate(effect, object_id)
	object_id = object_id or "effect"
	if type(effect) ~= "table" then
		return false, string.format("Effect in %s is not a table: %s", object_id, type(effect))
	end

	if not effect.effect_name or type(effect.effect_name) ~= "string" then
		return false, string.format("Effect in %s missing effect_name or not string", object_id)
	end

	if effect.sub then
		return false,
			string.format("Effect '%s' in %s uses removed field sub; use phase", effect.effect_name, object_id)
	end

	if effect.macro then
		return false,
			string.format("Effect '%s' in %s uses removed field macro; use action", effect.effect_name, object_id)
	end

	if not effect.action or not effect.phase then
		return false,
			string.format("Effect '%s' in %s missing action/phase scheduling fields", effect.effect_name, object_id)
	end

	if not VALID_ACTION[effect.action] then
		return false,
			string.format(
				"Effect '%s' in %s has invalid action '%s' (valid: %s)",
				effect.effect_name,
				object_id,
				effect.action,
				list_valid(VALID_ACTION)
			)
	end

	if not VALID_PHASES[effect.phase] then
		return false,
			string.format(
				"Effect '%s' in %s has invalid phase '%s' (valid: %s)",
				effect.effect_name,
				object_id,
				effect.phase,
				list_valid(VALID_PHASES)
			)
	end

	if effect.priority and type(effect.priority) ~= "number" then
		return false,
			string.format("Effect '%s' in %s has non-numeric priority: %s", effect.effect_name, object_id, type(effect.priority))
	end

	if effect.value and type(effect.value) ~= "number" and type(effect.value) ~= "table" then
		return false,
			string.format(
				"Effect '%s' in %s has invalid value type (expected number or table, got %s)",
				effect.effect_name,
				object_id,
				type(effect.value)
			)
	end

	if effect.duration and type(effect.duration) ~= "number" then
		return false,
			string.format("Effect '%s' in %s has non-numeric duration: %s", effect.effect_name, object_id, type(effect.duration))
	end

	if effect.conditions then
		local ok, err = ConditionSchema.validate_array(effect.conditions, object_id .. "." .. effect.effect_name)
		if not ok then
			return false, err
		end
	end

	return true
end

--- Return the configured point value scaled by scope multiplier.
function M.get_value(effect, scope_multiplier)
	if not effect.value then
		return 0
	end
	scope_multiplier = scope_multiplier or 1.0
	return effect.value * scope_multiplier
end

--- Whether the effect runs during the given scoring phase.
function M.applies_to_phase(effect, current_phase)
	return effect.phase == current_phase
end

--- Priority used when sorting collected effects.
function M.get_priority(effect)
	return effect.priority or 10
end

return M
