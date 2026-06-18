--- Shared resolved effect type → round scoring def mapping for resolver and AI.
--- @module objects.resolved_type_registry

local scheduling = require("objects.effects_conditions.scheduling")

local M = {}

local ON_PLAY = scheduling.ACTION.on_play
local PHASE_POINTS = scheduling.PHASE.points
local PHASE_MULT = scheduling.PHASE.mult

--- @param spec table
--- @param resolved table
--- @return string|number|nil
local function resolve_scheduling_field(spec, resolved)
	local def = resolved._effect_def or {}
	if spec.fixed ~= nil then
		return spec.fixed
	end
	local value = nil
	if spec.resolved then
		value = resolved[spec.resolved]
	end
	if value == nil and spec.effect_def then
		value = def[spec.effect_def]
	end
	return value or spec.default
end

--- @param field_spec string|table
--- @param resolved table
--- @return string|number|table|nil
local function resolve_carry_field(field_spec, resolved)
	local def = resolved._effect_def or {}
	if type(field_spec) == "string" then
		return resolved[field_spec]
	end
	local value = nil
	if field_spec.resolved then
		value = resolved[field_spec.resolved]
	end
	if value == nil and field_spec.effect_def and def[field_spec.effect_def] ~= nil then
		value = def[field_spec.effect_def]
	end
	if value == nil and field_spec.fallback and resolved[field_spec.fallback] ~= nil then
		value = resolved[field_spec.fallback]
	end
	if value == nil and field_spec.default ~= nil then
		value = field_spec.default
	end
	return value
end

--- @param spec table
--- @param resolved table
--- @return table
local function build_round_def(spec, resolved)
	local def = {
		effect_name = spec.effect_name,
		action = resolve_scheduling_field(spec.action, resolved),
		phase = resolve_scheduling_field(spec.phase, resolved),
	}
	for key, field_spec in pairs(spec.fields) do
		local value = resolve_carry_field(field_spec, resolved)
		if value ~= nil or field_spec.always then
			def[key] = value
		end
	end
	return def
end

local RESOLVED_TYPE_SPECS = {
	ADD_POINTS = {
		effect_name = "add_points",
		action = { fixed = ON_PLAY },
		phase = { fixed = PHASE_POINTS },
		fields = {
			value = "value",
			priority = { resolved = "priority", default = 10, always = true },
		},
		validate = "number_value",
	},
	ADD_MULT = {
		effect_name = "add_mult",
		action = { fixed = ON_PLAY },
		phase = { fixed = PHASE_MULT },
		fields = {
			value = "value",
			priority = { resolved = "priority", default = 10, always = true },
		},
		validate = "number_value",
	},
	ADD_ENERGY = {
		effect_name = "add_energy",
		action = { resolved = "action", default = ON_PLAY },
		phase = { resolved = "phase", default = PHASE_POINTS },
		fields = {
			value = "value",
			priority = { resolved = "priority", default = 10, always = true },
		},
		validate = "number_value",
	},
	ADD_MONEY = {
		effect_name = "add_money",
		action = { fixed = ON_PLAY },
		phase = { fixed = PHASE_POINTS },
		fields = {
			value = "value",
			priority = { resolved = "priority", default = 10, always = true },
		},
		validate = "money_value",
	},
	KAMIKAZE_SACRIFICE = {
		effect_name = "kamikaze_sacrifice",
		action = { fixed = ON_PLAY },
		phase = { fixed = PHASE_POINTS },
		fields = {
			value = "value",
			priority = { resolved = "priority", default = 10, always = true },
		},
		validate = "number_value",
	},
	SELF_DESTRUCT_SETUP = {
		effect_name = "self_destruct_setup",
		action = { fixed = ON_PLAY },
		phase = { fixed = PHASE_POINTS },
		fields = {
			immediate_points = "value",
			delay_rounds = "delay_rounds",
			priority = { resolved = "priority", default = 10, always = true },
		},
		validate = "number_value",
	},
	MONEY_FIELD_ENCLOSURE_PAYOUT = {
		effect_name = "money_field_enclosure_payout",
		action = { effect_def = "action", default = ON_PLAY },
		phase = { effect_def = "phase", default = PHASE_POINTS },
		fields = {
			value = { effect_def = "value" },
			priority = {
				resolved = "priority",
				effect_def = "priority",
				default = 10,
				always = true,
			},
		},
		validate = "always",
	},
	COPPER_THRESHOLD_PLUS_MULT = {
		effect_name = "copper_threshold_plus_mult",
		action = { effect_def = "action", default = ON_PLAY },
		phase = { effect_def = "phase", default = PHASE_MULT },
		fields = {
			value = { effect_def = "value", fallback = "value" },
			conditions = { effect_def = "conditions" },
			priority = {
				resolved = "priority",
				effect_def = "priority",
				default = 10,
				always = true,
			},
		},
		validate = "always",
	},
	FINAL_BLOW_PLACEMENT = {
		effect_name = "final_blow_placement",
		action = { fixed = ON_PLAY },
		phase = { fixed = PHASE_POINTS },
		fields = {
			priority = { resolved = "priority", default = 10, always = true },
		},
		validate = "always",
	},
	RETRIGGER_PRIOR_STONE_EFFECT = {
		effect_name = "retrigger_prior_stone_effect",
		action = { fixed = ON_PLAY },
		phase = { fixed = PHASE_POINTS },
		fields = {
			priority = { resolved = "priority", default = 10, always = true },
		},
		validate = "always",
	},
	ESCALATING_POINTS_INIT = {
		effect_name = "escalating_points_bank",
		action = { fixed = ON_PLAY },
		phase = { fixed = PHASE_POINTS },
		fields = {
			priority = { resolved = "priority", default = 10, always = true },
		},
		validate = "always",
	},
	ANTI_CAPTURE_SETUP = {
		validate = "always",
	},
}

local VALIDATORS = {
	number_value = function(resolved)
		return type(resolved.value) == "number"
	end,
	money_value = function(resolved)
		return type(resolved.value) == "table" and type(resolved.value.amount) == "number"
	end,
	always = function(_resolved)
		return true
	end,
}

M.RESOLVED_TYPE_SPECS = RESOLVED_TYPE_SPECS

--- @param resolved table|nil
--- @return table|nil
function M.round_effect_def_from_resolved(resolved)
	if not resolved or not resolved.type then
		return nil
	end
	local spec = RESOLVED_TYPE_SPECS[resolved.type]
	if not spec or not spec.effect_name then
		return nil
	end
	return build_round_def(spec, resolved)
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
	local spec = RESOLVED_TYPE_SPECS[resolved.type]
	if not spec then
		return false
	end
	local validator = VALIDATORS[spec.validate]
	return validator(resolved)
end

return M
