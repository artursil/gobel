local definitions = require("poses.definitions")

local M = {}

local function side_to_owner(side)
	if side == "white" or side == "B" then
		return "B"
	end
	return "A"
end

local function phase_for_effect(effect)
	if effect.type == "ADD_POINTS" then
		return "points"
	end
	return "mult"
end

local function build_generator(pose_id)
	return function(pose, state)
		local pose_def = definitions[pose_id]
		if not pose_def or not pose_def.effect then
			return {}
		end
		local owner = pose.owner
		if owner ~= "A" and owner ~= "B" then
			owner = side_to_owner(owner)
		end
		local effect = pose_def.effect
		local phase = phase_for_effect(effect)
		return {
			{
				phase = phase,
				priority = effect.priority or 20,
				apply = function(current_state)
					print("[Effect Triggered]", pose.type, phase)
					if phase == "points" then
						current_state.scores.points[owner] = current_state.scores.points[owner] + effect.value
					else
						current_state.scores.mult[owner] = current_state.scores.mult[owner] + effect.value
					end
				end,
			},
		}
	end
end

for pose_id, _ in pairs(definitions) do
	M[pose_id] = build_generator(pose_id)
end

return M
