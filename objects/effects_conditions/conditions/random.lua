--- Probabilistic gate using condition_def.probability or condition_def.value.
--- @module objects.effects_conditions.conditions.random

local match_state = require("match_state")

local M = {}

--- Roll against probability; fractional rolls require state.rng for replay safety.
function M.eval(state, _owner, condition_def)
	local probability = condition_def and (condition_def.probability or condition_def.value) or nil
	if probability == nil then
		return false, nil
	end
	if probability <= 0 then
		return false, nil
	end
	if probability >= 1 then
		return true, nil
	end
	if not state or not state.rng then
		return false, nil
	end
	local roll = match_state.rng_next_int(state, 10000)
	if roll <= math.floor(probability * 10000) then
		return true, nil
	end
	return false, nil
end

return M
