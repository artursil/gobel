--- Placement helper: mutates score points for the placing owner.
--- @module objects.helper_effects.add_points

local M = {}

--- @param state table
--- @param owner string
--- @param value number
--- @return nil
function M.apply(state, owner, value)
	state.scores.points[owner] = state.scores.points[owner] + value
end

return M
