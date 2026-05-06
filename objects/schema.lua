--- Schema validation for unified game objects.
--- Enforces consistent structure across stones, cards, and stances.
--- @module objects.schema

local M = {}

--- Valid object types
local VALID_TYPES = { stone = true, card = true, stance = true }

--- Valid rarity tiers
local VALID_RARITIES = { common = true, uncommon = true, rare = true, epic = true, legendary = true }

--- Valid effect phases
local VALID_PHASES = {
	distance = true,
	territory = true,
	points = true,
	mult = true,
	hand = true,
	discard = true,
}

--- Valid effect scopes (optional)
local VALID_SCOPES = {
	self = true,
	board = true,
	hand = true,
	opponent = true,
	all = true,
}

--- Helper: list valid values from a table
local function list_valid(tbl)
	local result = {}
	for key in pairs(tbl) do
		table.insert(result, key)
	end
	table.sort(result)
	return table.concat(result, ", ")
end

--- Validate a single effect entry against unified schema.
--- @param effect table: Effect definition to validate
--- @param object_id string: Object containing this effect (for error messages)
--- @return boolean: true if valid
--- @return string|nil: error message if invalid
local function validate_effect(effect, object_id)
	if type(effect) ~= "table" then
		return false, string.format("Effect in %s is not a table: %s", object_id, type(effect))
	end

	if not effect.effect_name or type(effect.effect_name) ~= "string" then
		return false, string.format("Effect in %s missing effect_name or not string", object_id)
	end

	if not effect.phase or type(effect.phase) ~= "string" then
		return false, string.format("Effect '%s' in %s missing phase or not string", effect.effect_name, object_id)
	end

	if not VALID_PHASES[effect.phase] then
		return false, string.format(
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

	return true
end

--- Validate a complete object definition (stone, card, or stance).
--- @param object table: Object definition to validate
--- @param object_type string: "stone", "card", or "stance"
--- @return boolean: true if valid
--- @return string|nil: error message if invalid
function M.validate_object(object, object_type)
	if type(object) ~= "table" then
		return false, string.format("Object is not a table: %s", type(object))
	end

	if not object.id or type(object.id) ~= "string" then
		return false, "Object missing id or id not string"
	end

	if not object.type or object.type ~= object_type then
		return false,
			string.format("Object %s has wrong type (expected '%s', got '%s')", object.id, object_type, object.type)
	end

	if not object.name or type(object.name) ~= "string" then
		return false, string.format("Object %s missing name or name not string", object.id)
	end

	if not object.description or type(object.description) ~= "string" then
		return false, string.format("Object %s missing description or description not string", object.id)
	end

	if object.cost == nil or type(object.cost) ~= "number" then
		return false, string.format("Object %s missing cost or cost not number", object.id)
	end

	if object.cost < 0 then
		return false, string.format("Object %s has negative cost: %d", object.id, object.cost)
	end

	if object.rarity and not VALID_RARITIES[object.rarity] then
		return false,
			string.format(
				"Object %s has invalid rarity '%s' (valid: %s)",
				object.id,
				object.rarity,
				list_valid(VALID_RARITIES)
			)
	end

	if object.probability then
		if type(object.probability) ~= "number" or object.probability < 0 or object.probability > 1 then
			return false,
				string.format("Object %s has invalid probability %s (must be number between 0 and 1)", object.id, object.probability)
		end
	end

	if not object.effects or type(object.effects) ~= "table" then
		return false, string.format("Object %s missing effects or effects not table", object.id)
	end

	for i, effect in ipairs(object.effects) do
		local valid, err = validate_effect(effect, object.id)
		if not valid then
			return false,
				string.format("Object %s, effect #%d: %s", object.id, i, err)
		end
	end

	return true
end

--- Validate all objects in a definition table.
--- @param definitions table: Map of id -> object definitions
--- @param object_type string: "stone", "card", or "stance"
--- @return boolean: true if all valid
--- @return table: Array of error messages (empty if all valid)
function M.validate_all(definitions, object_type)
	local errors = {}

	for id, obj in pairs(definitions) do
		local valid, err = M.validate_object(obj, object_type)
		if not valid then
			table.insert(errors, err)
		end
	end

	return #errors == 0, errors
end

return M
