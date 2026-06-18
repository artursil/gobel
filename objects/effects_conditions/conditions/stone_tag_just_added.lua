--- Pass when the last placed stone carries a configured tag.
--- @module objects.effects_conditions.conditions.stone_tag_just_added

local queries = require("single_game.resolver.helpers.state_queries")

local M = {}

--- Match tag on the most recently placed stone.
function M.eval(state, _owner, condition_def)
	if not condition_def or not condition_def.tag then
		return false, nil
	end
	local last_stone = queries.last_placed_stone(state)
	if not last_stone then
		return false, nil
	end
	local placed_stone_tags = last_stone.tags or {}
	for _, tag in ipairs(placed_stone_tags) do
		if tag == condition_def.tag then
			return true, nil
		end
	end
	return false, nil
end

return M
