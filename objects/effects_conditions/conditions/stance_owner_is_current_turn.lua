--- Pass when the stance source owner matches the current turn owner.
--- @module objects.effects_conditions.conditions.stance_owner_is_current_turn

local queries = require("single_game.resolver.helpers.state_queries")

local M = {}

--- Compare source owner to current turn owner.
function M.eval(state, _owner, _condition_def)
	local source_owner = queries.source_owner(state)
	local turn_owner = queries.current_turn_owner(state)
	if source_owner ~= nil and turn_owner ~= nil and source_owner == turn_owner then
		return true, nil
	end
	return false, nil
end

return M
