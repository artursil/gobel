--- Stance utility module: active stances enumeration and trigger dispatch.
--- Temporary location: will be unified into objects/ in PR 2.
--- @module stances

local content = require("content")

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

--- Dispatch trigger: call callback for each active stance matching trigger_name.
--- @param player_state table
--- @param trigger_name string
--- @param callback function(stance_id, stance_def)
function M.dispatch_trigger(player_state, trigger_name, callback)
	for_each_active_stance_id(player_state, function(stance_id)
		local stance_def = content.get_stance(stance_id)
		if stance_def and stance_def.trigger == trigger_name then
			callback(stance_id, stance_def)
		end
	end)
end

return M
