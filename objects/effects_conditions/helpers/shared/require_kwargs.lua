--- Validates that required kwargs keys are present before effect apply.
--- @module objects.effects_conditions.helpers.shared.require_kwargs

local M = {}

--- Error when any required key is absent from kwargs.
function M.require_kwargs(kwargs, required_keys)
	if type(kwargs) ~= "table" then
		error("kwargs must be a table")
	end
	for i = 1, #required_keys do
		local key = required_keys[i]
		if kwargs[key] == nil then
			error(string.format("missing required kwargs key: %s", tostring(key)))
		end
	end
end

return M
