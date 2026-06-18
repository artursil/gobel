--- Pass when the source temporary stance still has remaining rounds.
--- @module objects.effects_conditions.conditions.temporary_stance_active

local ObjectInstance = require("single_game.resolver.ObjectInstance")
local queries = require("single_game.resolver.helpers.state_queries")

local M = {}

--- Pass when no stance instance or instance is not expired.
function M.eval(state, _owner, _condition_def)
	local instance = queries.source_stance_instance(state)
	if not instance then
		return true, nil
	end
	if not ObjectInstance.is_expired(instance) then
		return true, nil
	end
	return false, nil
end

return M
