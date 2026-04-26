local content = require("content")

local M = {}

local function for_each_active_pose_id(player_state, visitor)
	local pose_slots = player_state.poses
	for i = 1, #pose_slots.fixed do
		visitor(pose_slots.fixed[i])
	end
	for i = 1, #pose_slots.swappable do
		visitor(pose_slots.swappable[i])
	end
end

function M.active_pose_ids(player_state)
	local out = {}
	for_each_active_pose_id(player_state, function(pose_id)
		out[#out + 1] = pose_id
	end)
	return out
end

function M.dispatch_trigger(player_state, trigger_name, callback)
	for_each_active_pose_id(player_state, function(pose_id)
		local pose_def = content.get_pose(pose_id)
		if pose_def and pose_def.trigger == trigger_name then
			callback(pose_id, pose_def)
		end
	end)
end

return M
