--- Kamikaze placement points; board removal runs in ``remove_stones`` stage.
--- @module objects.helper_effects.kamikaze_sacrifice

local M = {}

--- @param state table
--- @param owner string
--- @param value number
--- @return nil
function M.apply(state, owner, value)
	state.scores.points[owner] = state.scores.points[owner] + value
end

return M
