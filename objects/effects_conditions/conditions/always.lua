--- Pass-through condition that always succeeds.
--- @module objects.effects_conditions.conditions.always

local M = {}

--- Always returns pass.
function M.eval(_state, _owner, _condition_def)
	return true, nil
end

return M
