--- Placement helper: mutates score plus_mult for the placing owner.
--- @module objects.helper_effects.add_mult

local M = {}

--- @param state table
--- @param owner string
--- @param value number
--- @return nil
function M.apply(state, owner, value)
	state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + value
end

return M
