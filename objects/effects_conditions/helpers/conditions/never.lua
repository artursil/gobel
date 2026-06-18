--- Gate condition that always fails.
--- @module objects.effects_conditions.helpers.conditions.never

local M = {}

--- Always returns fail.
function M.eval(_state, _owner, _condition_def)
	return false, nil
end

return M
