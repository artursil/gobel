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

return M
