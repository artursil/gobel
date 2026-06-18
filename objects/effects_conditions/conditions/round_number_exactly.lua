--- Pass when match round_number equals condition_def.value.
--- @module objects.effects_conditions.conditions.round_number_exactly

local M = {}

--- Exact round number match.
function M.eval(state, _owner, condition_def)
	local value = condition_def and condition_def.value
	if value == nil or not state then
		return false, nil
	end
	if (state.round_number or 1) == value then
		return true, nil
	end
	return false, nil
end

return M
