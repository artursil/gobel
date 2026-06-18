--- Schema validation for unified game objects.
--- Stone effects declare ``action`` + ``phase``.
--- @module objects.schema

local EffectSchema = require("objects.effects_conditions.EffectSchema")

local M = {}

local VALID_TYPES = { stone = true, card = true, stance = true }

local VALID_RARITIES = { common = true, uncommon = true, rare = true, epic = true, legendary = true }

local VALID_PLAY_MODES = {
	instant = true,
	target_single = true,
	target_multi = true,
}

local VALID_TARGET_OBJECT_TYPES = {
	stone = true,
	card = true,
	stance = true,
}

local VALID_TARGET_OWNERS = {
	self = true,
	opponent = true,
	any = true,
}

local function validate_string_list(value, field_name, object_id)
	if value == nil then
		return true, nil
	end
	if type(value) ~= "table" then
		return false, string.format("Object %s field %s must be an array", object_id, field_name)
	end
	for i = 1, #value do
		if type(value[i]) ~= "string" then
			return false, string.format("Object %s field %s[%d] must be string", object_id, field_name, i)
		end
	end
	return true, nil
end

local function list_valid(tbl)
	local result = {}
	for key in pairs(tbl) do
		table.insert(result, key)
	end
	table.sort(result)
	return table.concat(result, ", ")
end

--- @param object table
--- @param object_type string
--- @return boolean
--- @return string|nil
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

	if object_type == "stone" and object.solidity ~= nil then
		if type(object.solidity) ~= "number" or object.solidity < 1 or object.solidity ~= math.floor(object.solidity) then
			return false,
				string.format("Object %s has invalid solidity (expected positive integer, got %s)", object.id, tostring(object.solidity))
		end
	end

	if not object.effects or type(object.effects) ~= "table" then
		return false, string.format("Object %s missing effects or effects not table", object.id)
	end

	if object_type == "card" then
		local play_mode = object.play_mode or "instant"
		if not VALID_PLAY_MODES[play_mode] then
			return false, string.format("Object %s has invalid play_mode '%s'", object.id, tostring(play_mode))
		end
		if play_mode ~= "instant" then
			if not VALID_TARGET_OBJECT_TYPES[object.target_object_type] then
				return false,
					string.format("Object %s has invalid target_object_type '%s'", object.id, tostring(object.target_object_type))
			end
			local target_owner = object.target_owner or "any"
			if not VALID_TARGET_OWNERS[target_owner] then
				return false, string.format("Object %s has invalid target_owner '%s'", object.id, tostring(target_owner))
			end
		end
		local ok_list, list_err = validate_string_list(object.required_tags_all, "required_tags_all", object.id)
		if not ok_list then
			return false, list_err
		end
		ok_list, list_err = validate_string_list(object.required_tags_any, "required_tags_any", object.id)
		if not ok_list then
			return false, list_err
		end
		ok_list, list_err = validate_string_list(object.excluded_tags, "excluded_tags", object.id)
		if not ok_list then
			return false, list_err
		end
		if object.min_targets ~= nil and (type(object.min_targets) ~= "number" or object.min_targets < 0) then
			return false, string.format("Object %s has invalid min_targets", object.id)
		end
		if object.max_targets ~= nil and (type(object.max_targets) ~= "number" or object.max_targets < 0) then
			return false, string.format("Object %s has invalid max_targets", object.id)
		end
	end

	for i, effect in ipairs(object.effects) do
		local valid, err = EffectSchema.validate(effect, object.id)
		if not valid then
			return false, string.format("Object %s, effect #%d: %s", object.id, i, err)
		end
	end

	return true
end

--- @param definitions table
--- @param object_type string
--- @return boolean
--- @return table
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

M.VALID_ACTION = EffectSchema.VALID_ACTION
M.VALID_PHASES = EffectSchema.VALID_PHASES

return M
