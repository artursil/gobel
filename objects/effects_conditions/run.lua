--- Runner: evaluate conditions, merge kwargs, invoke effect apply.
--- @module objects.effects_conditions.run

local conditions = require("objects.effects_conditions.conditions")

local M = {}

--- Merge condition fragments into one kwargs table.
local function merge_kwargs(kwargs, fragment)
	for key, value in pairs(fragment) do
		kwargs[key] = value
	end
end

--- Evaluate all conditions on a collected effect; call apply when every condition passes.
function M.apply_effect(effect, state, owner)
	local kwargs = {}
	for _, condition_def in ipairs(effect.conditions or {}) do
		local pass, fragment = conditions.eval(condition_def, state, owner)
		if not pass then
			return false
		end
		if fragment then
			merge_kwargs(kwargs, fragment)
		end
	end
	if effect.apply then
		effect.apply(state, owner, kwargs)
	end
	return true
end

return M
