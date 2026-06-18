--- Condition definition schema: shape validation for effect gating rows.
--- @module objects.effects_conditions.ConditionSchema

local M = {}

M.KNOWN_CONDITION_NAMES = {
	always = true,
	never = true,
	random = true,
	stone_tag_just_added = true,
	temporary_stance_expired = true,
	temporary_stance_active = true,
	stance_owner_is_current_turn = true,
	round_number_exactly = true,
	round_number_at_least = true,
	selected_target_exists = true,
	selected_target_is_enemy_stone = true,
	selected_target_is_friendly_stone = true,
	owner_coppers_on_board_at_least = true,
	wall_part_of_wall = true,
}

--- Known kwargs keys produced by each condition (when not declared on the row).
M.CONDITION_KWARGS_KEYS = {
	wall_part_of_wall = { "blocks" },
}

local REJECTED_FIELDS = {
	sub = "use condition_name and params on condition rows",
	action = "belongs on effect rows, not conditions",
	phase = "belongs on effect rows, not conditions",
	macro = "belongs on effect rows, not conditions",
	when = "belongs on effect rows, not conditions",
	effect_name = "belongs on effect rows, not conditions",
	lifecycle = "belongs on effect rows, not conditions",
	priority = "belongs on effect rows, not conditions",
	duration = "belongs on effect rows, not conditions",
	scope = "belongs on effect rows, not conditions",
}

local function list_known_names()
	local names = {}
	for name in pairs(M.KNOWN_CONDITION_NAMES) do
		table.insert(names, name)
	end
	table.sort(names)
	return table.concat(names, ", ")
end

--- Return kwargs keys declared on the row or inferred from the registry.
local function kwargs_keys_for(condition_def)
	if condition_def.kwargs_keys ~= nil then
		return condition_def.kwargs_keys
	end
	return M.CONDITION_KWARGS_KEYS[condition_def.condition_name] or {}
end

--- Validate optional kwargs_keys field on a condition row.
local function validate_kwargs_keys_field(condition_def, context_id)
	if condition_def.kwargs_keys == nil then
		return true
	end
	if type(condition_def.kwargs_keys) ~= "table" then
		return false,
			string.format(
				"Condition '%s' in %s has non-table kwargs_keys",
				condition_def.condition_name,
				context_id
			)
	end
	for i = 1, #condition_def.kwargs_keys do
		if type(condition_def.kwargs_keys[i]) ~= "string" then
			return false,
				string.format(
					"Condition '%s' in %s kwargs_keys[%d] is not a string",
					condition_def.condition_name,
					context_id,
					i
				)
		end
	end
	return true
end

--- Reject duplicate kwargs keys across conditions on one effect.
function M.validate_kwargs_collisions(conditions, context_id)
	if not conditions or #conditions < 2 then
		return true
	end
	local seen = {}
	for i = 1, #conditions do
		local keys = kwargs_keys_for(conditions[i])
		for j = 1, #keys do
			local key = keys[j]
			if seen[key] then
				return false,
					string.format(
						"Duplicate kwargs key '%s' in %s (conditions #%d and #%d)",
						key,
						context_id,
						seen[key],
						i
					)
			end
			seen[key] = i
		end
	end
	return true
end

--- Validate a single condition definition row.
function M.validate(condition_def, context_id)
	context_id = context_id or "condition"
	if type(condition_def) ~= "table" then
		return false, string.format("Condition in %s is not a table: %s", context_id, type(condition_def))
	end

	for field, hint in pairs(REJECTED_FIELDS) do
		if condition_def[field] ~= nil then
			return false,
				string.format("Condition in %s uses removed field %s; %s", context_id, field, hint)
		end
	end

	if not condition_def.condition_name or type(condition_def.condition_name) ~= "string" then
		return false, string.format("Condition in %s missing condition_name or not string", context_id)
	end

	if not M.KNOWN_CONDITION_NAMES[condition_def.condition_name] then
		return false,
			string.format(
				"Condition in %s has unknown condition_name '%s' (valid: %s)",
				context_id,
				condition_def.condition_name,
				list_known_names()
			)
	end

	if condition_def.value ~= nil and type(condition_def.value) ~= "number" then
		return false,
			string.format(
				"Condition '%s' in %s has non-numeric value: %s",
				condition_def.condition_name,
				context_id,
				type(condition_def.value)
			)
	end

	if condition_def.probability ~= nil then
		if type(condition_def.probability) ~= "number" or condition_def.probability < 0 or condition_def.probability > 1 then
			return false,
				string.format(
					"Condition '%s' in %s has invalid probability (must be number between 0 and 1)",
					condition_def.condition_name,
					context_id
				)
		end
	end

	if condition_def.tag ~= nil and type(condition_def.tag) ~= "string" then
		return false,
			string.format(
				"Condition '%s' in %s has non-string tag",
				condition_def.condition_name,
				context_id
			)
	end

	if condition_def.params ~= nil and type(condition_def.params) ~= "table" then
		return false,
			string.format(
				"Condition '%s' in %s has non-table params",
				condition_def.condition_name,
				context_id
			)
	end

	local ok_keys, err_keys = validate_kwargs_keys_field(condition_def, context_id)
	if not ok_keys then
		return false, err_keys
	end

	return true
end

--- Validate an array of condition rows (nil or empty passes).
function M.validate_array(conditions, context_id)
	if conditions == nil then
		return true
	end
	if type(conditions) ~= "table" then
		return false, string.format("Conditions in %s must be an array", context_id or "object")
	end
	for i = 1, #conditions do
		local ok, err = M.validate(conditions[i], string.format("%s condition #%d", context_id or "object", i))
		if not ok then
			return false, err
		end
	end
	local ok_collisions, err_collisions = M.validate_kwargs_collisions(conditions, context_id or "object")
	if not ok_collisions then
		return false, err_collisions
	end
	return true
end

return M
