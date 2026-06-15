--- Immediate placement points plus a removal timer on the placed cell.
--- @module objects.helper_effects.self_destruct_timed

local board_cell_timers = require("single_game.resolver.board_cell_timers")

local M = {}

--- @param state table
--- @param owner string
--- @param immediate_points number
--- @param delay_rounds integer
--- @param row integer|nil
--- @param col integer|nil
--- @return nil
function M.apply(state, owner, immediate_points, delay_rounds, row, col)
	state.scores.points[owner] = state.scores.points[owner] + immediate_points
	if row and col then
		board_cell_timers.register(state, row, col, delay_rounds)
	end
end

return M
