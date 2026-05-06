--- Unified condition evaluation registry (stub for PR 1).
--- Temporary location: will consolidate all condition logic here in PR 3.
--- Currently a placeholder for future condition system.
--- @module objects.conditions

local M = {}

--- Evaluate a condition against state and context.
--- Stub implementation: always returns true.
--- @param condition_name string
--- @param state table
--- @param context table
--- @return boolean
function M.eval(condition_name, state, context)
	-- Placeholder for PR 3 unification.
	-- Future implementation will dispatch to condition handlers.
	return true
end

return M
