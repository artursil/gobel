--- Stance utility module: active stances enumeration.
--- @module stances

local M = {}

--- Iterate all active stance IDs (fixed + swappable).
--- @param player_state table
--- @param visitor function(stance_id)
local function for_each_active_stance_id(player_state, visitor)
	local stance_slots = player_state.stances
	for i = 1, #stance_slots.fixed do
		visitor(stance_slots.fixed[i])
	end
	for i = 1, #stance_slots.swappable do
		visitor(stance_slots.swappable[i])
	end
end

--- Get all active stance IDs for a player.
--- @param player_state table
--- @return table list of stance IDs
function M.active_stance_ids(player_state)
	local out = {}
	for_each_active_stance_id(player_state, function(stance_id)
		out[#out + 1] = stance_id
	end)
	return out
end

--- Get all active stance entries (IDs + instances) including temporary stances.
--- @param player_state table
--- @param game_state table: The global game state containing temporary_stances
--- @param owner string: `config.OWNER_BLACK` or `config.OWNER_WHITE` to filter temporary stances by owner
--- @return table list of {id=stance_id, duration=remaining_rounds_or_nil}
function M.all_active_stances(player_state, game_state, owner)
	local out = {}
	
	for_each_active_stance_id(player_state, function(stance_id)
		out[#out + 1] = { id = stance_id, duration = nil }
	end)
	
	if game_state and game_state.temporary_stances then
		for _, temp_stance in ipairs(game_state.temporary_stances) do
			if temp_stance.owner == owner then
				out[#out + 1] = { id = temp_stance.def_id, duration = temp_stance.duration.remaining_rounds }
			end
		end
	end
	
	return out
end

return M
