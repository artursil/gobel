--- Unified condition evaluation registry.
--- All conditions evaluate through this dispatcher.
--- Conditions can gate effect application or be evaluated in action context.
--- @module objects.conditions

local M = {}

--- Always true condition.
--- @param context table
--- @return boolean
function M.always(context)
	return true
end

--- Always false condition.
--- @param context table
--- @return boolean
function M.never(context)
	return false
end

--- Random chance condition (requires context.rng and context.probability).
--- @param context table: {rng?, probability?}
--- @return boolean
function M.random(context)
	if not context or not context.probability then
		return false
	end
	if context.probability <= 0 then
		return false
	end
	if context.probability >= 1 then
		return true
	end
	if context.rng then
		return context.rng:random() < context.probability
	end
	return math.random() < context.probability
end

--- Evaluate a single condition.
--- Dispatch by condition name; return true if unknown (fail-safe).
--- @param condition_def table: {condition_name, ...params...}
--- @param context table: {rng?, probability?, state?, owner?, ...}
--- @return boolean
local function eval_single(condition_def, context)
	if not condition_def then
		return true
	end
	if not condition_def.condition_name then
		return true
	end
	local evaluator = M[condition_def.condition_name]
	if not evaluator then
		return true
	end
	return evaluator(condition_def, context)
end

--- Evaluate an array of conditions (all must pass).
--- Returns true if conditions array is nil or empty (no conditions = always pass).
--- Returns false if any condition fails (fail-fast on first false).
--- @param conditions table|nil: array of {condition_name, ...}
--- @param context table: evaluation context
--- @return boolean
function M.eval_all(conditions, context)
	if not conditions or #conditions == 0 then
		return true
	end
	for i = 1, #conditions do
		if not eval_single(conditions[i], context) then
			return false
		end
	end
	return true
end

--- Evaluate a single condition by name (convenience function).
--- @param condition_name string
--- @param context table
--- @return boolean
function M.eval(condition_name, context)
	local evaluator = M[condition_name]
	if not evaluator then
		return true
	end
	return evaluator(context)
end

return M
