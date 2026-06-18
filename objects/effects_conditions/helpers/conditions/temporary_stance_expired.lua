--- Pass when the source temporary stance has no remaining rounds.
--- @module objects.effects_conditions.helpers.conditions.temporary_stance_expired

local ObjectInstance = require("single_game.resolver.ObjectInstance")
local queries = require("single_game.resolver.helpers.state_queries")

local M = {}

--- Fail when no stance instance; pass when instance is expired.
function M.eval(state, _owner, _condition_def)
	local instance = queries.source_stance_instance(state)
	if not instance then
		return false, nil
	end
	if ObjectInstance.is_expired(instance) then
		return true, nil
	end
	return false, nil
end

return M
