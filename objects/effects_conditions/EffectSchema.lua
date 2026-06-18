--- Effect definition schema: validation, runtime instances, EffectSchema.build factory.
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
VALID_ACTION.board_reconcile = true

local VALID_WHEN = {
	game_start = true,
	before_turn = true,
	playing_cards = true,
	playing_stones = true,
	board_reconcile = true,
	end_of_turn = true,
	on_removed = true,
	game_end = true,
	tick = true,
	on_card = true,
	on_play = true,
}

local VALID_PHASES = {
	territory = true,
	points = true,
	mult = true,
}

local VALID_LIFECYCLES = {
	placement = true,
	board_reconcile = true,
}

local VALID_SCOPES = {
	self = true,
	board = true,
	hand = true,
	opponent = true,
	all = true,
}

M.VALID_ACTION = VALID_ACTION
M.VALID_WHEN = VALID_WHEN
M.VALID_PHASES = VALID_PHASES
M.VALID_LIFECYCLES = VALID_LIFECYCLES
M.VALID_SCOPES = VALID_SCOPES

local function list_valid(tbl)
	local result = {}
	for key in pairs(tbl) do
		table.insert(result, key)
	end
	table.sort(result)
	return table.concat(result, ", ")
end

local OPTIONAL_DEF_FIELDS = {
	"territory_step",
	"delay_rounds",
	"immediate_points",
	"rounds",
	"payout",
	"stone_kind",
}

--- Merge runtime kwargs with definition defaults (definition wins on key collision).
function M.merge_kwargs(kwargs, defaults)
	local merged = {}
	for key, value in pairs(kwargs or {}) do
		merged[key] = value
	end
	for key, value in pairs(defaults or {}) do
		merged[key] = value
	end
	return merged
end

--- Build a normalized effect instance from a definition row.
function M.new(effect_def)
	local action, phase = scheduling.parse_action_phase(effect_def)
	local instance = {
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
	for i = 1, #OPTIONAL_DEF_FIELDS do
		local key = OPTIONAL_DEF_FIELDS[i]
		if effect_def[key] ~= nil then
			instance[key] = effect_def[key]
		end
	end
	return instance
end

--- Build a resolved runtime instance from a definition row and builder output.
function M.build(effect_def, opts)
	opts = opts or {}
	local action, phase = scheduling.parse_action_phase(effect_def)
	local instance = {
		type = opts.type,
		effect_name = effect_def.effect_name,
		action = action or opts.default_action or scheduling.ACTION.on_play,
		phase = phase or opts.default_phase or scheduling.PHASE.points,
		priority = effect_def.priority or opts.default_priority or 10,
		value = effect_def.value,
		params = effect_def.params or {},
		duration = effect_def.duration,
		scope = effect_def.scope or "game",
		probability = effect_def.probability,
		conditions = effect_def.conditions or opts.conditions,
		target = effect_def.target or {
			selector = "self",
			filters = {},
		},
		tags = effect_def.tags or {},
	}
	for i = 1, #OPTIONAL_DEF_FIELDS do
		local key = OPTIONAL_DEF_FIELDS[i]
		if effect_def[key] ~= nil then
			instance[key] = effect_def[key]
		end
	end
	if opts.extra then
		for key, value in pairs(opts.extra) do
			instance[key] = value
		end
	end
	local apply_fn = opts.apply
	if apply_fn then
		local kwargs_from_def = opts.kwargs_from_def
		instance.apply = function(state, owner, kwargs)
			local defaults = kwargs_from_def and kwargs_from_def(effect_def, instance) or {}
			apply_fn(state, owner, M.merge_kwargs(kwargs, defaults))
		end
	end
	if opts.on_tick then
		instance.on_tick = opts.on_tick
	end
	return instance
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

	if effect.action and effect.phase then
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
	elseif effect.when and effect.phase then
		if not VALID_WHEN[effect.when] then
			return false,
				string.format(
					"Effect '%s' in %s has invalid when '%s' (valid: %s)",
					effect.effect_name,
					object_id,
					effect.when,
					list_valid(VALID_WHEN)
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
	elseif effect.phase and type(effect.phase) == "string" then
	else
		return false,
			string.format("Effect '%s' in %s missing action/phase scheduling fields", effect.effect_name, object_id)
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

	if effect.scope and not VALID_SCOPES[effect.scope] then
		return false,
			string.format(
				"Effect '%s' in %s has invalid scope '%s' (valid: %s)",
				effect.effect_name,
				object_id,
				effect.scope,
				list_valid(VALID_SCOPES)
			)
	end

	if effect.lifecycle and not VALID_LIFECYCLES[effect.lifecycle] then
		return false,
			string.format(
				"Effect '%s' in %s has invalid lifecycle '%s' (valid: %s)",
				effect.effect_name,
				object_id,
				effect.lifecycle,
				list_valid(VALID_LIFECYCLES)
			)
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
