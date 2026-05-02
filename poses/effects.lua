--- Pose effect builders: point/mult deltas registered for the scoring resolver.
--- @module poses.effects

local definitions = require("poses.definitions")

local M = {}

--- @param side string
--- @return string
local function side_to_owner(side)
	if side == "white" or side == "B" then
		return "B"
	end
	return "A"
end

--- @param pose table
--- @param owner string
--- @param value number
--- @param priority integer|nil
--- @return table
function M.add_points(pose, owner, value, priority, phase)
	return {
		phase = phase or "points",
		priority = priority or 20,
		apply = function(state)
			print("[Effect Triggered]", pose.type, "points")
			state.scores.points[owner] = state.scores.points[owner] + value
		end,
	}
end

--- @param pose table
--- @param owner string
--- @param value number
--- @param priority integer|nil
--- @return table
function M.add_mult(pose, owner, value, priority, phase)
	return {
		phase = phase or "mult",
		priority = priority or 20,
		apply = function(state)
			print("[Effect Triggered]", pose.type, "mult")
			state.scores.mult[owner] = state.scores.mult[owner] + value
		end,
	}
end

--- Returns zero or one effect table from `poses.definitions` for this pose type.
--- @param pose table
--- @param _state table
--- @return table
function M.resolve(pose, _state)
	local pose_def = definitions[pose.type]
	if not pose_def or not pose_def.effects then
		return {}
	end
	local owner = pose.owner
	if owner ~= "A" and owner ~= "B" then
		owner = side_to_owner(owner)
	end
	local out = {}
	for i = 1, #pose_def.effects do
		local e = pose_def.effects[i]
		local effect_builder = M[e.effect_name]
		if effect_builder then
			out[#out + 1] = effect_builder(pose, owner, e.value, e.priority, e.phase)
		end
	end
	return out
end

return M
