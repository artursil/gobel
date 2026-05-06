--- DEPRECATED: Compatibility shim for poses.definitions
--- All definitions moved to objects/definitions/stances.lua
--- Map old pose IDs to new stance IDs for backward compatibility
--- REMOVAL PLAN: Delete after PR 2 when all callers migrate to objects/
--- @module poses.definitions

local stances = require("objects.definitions.stances")

local M = {}

--- Map old pose IDs to new stance IDs for backward compatibility
local ID_MAP = {
	pose_point_stance = "stance_point",
	pose_mult_stance = "stance_mult",
	pose_heavy_point_stance = "stance_heavy_point",
}

--- Copy all stances with old IDs for compatibility
for old_id, new_id in pairs(ID_MAP) do
	local stance_def = stances[new_id]
	if stance_def then
		M[old_id] = {
			id = old_id,  -- keep old ID for compat
			display_name = stance_def.display_name,
			trigger = stance_def.trigger,
			effects = stance_def.effects,
		}
	end
end

return M
