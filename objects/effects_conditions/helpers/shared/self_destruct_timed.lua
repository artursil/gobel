--- Self-destruct timed stone: immediate points on play, removal enqueue when timer expires.
--- @module objects.effects_conditions.helpers.shared.self_destruct_timed

local board = require("board")
local duration_left = require("objects.effects_conditions.helpers.shared.duration_left")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")
local placement = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

--- @param state table
--- @param owner string
--- @param immediate_points number
--- @param delay_rounds integer
--- @param row integer|nil
--- @param col integer|nil
--- @return nil
function M.setup_on_play(state, owner, immediate_points, delay_rounds, row, col)
	state.scores.points[owner] = state.scores.points[owner] + immediate_points
	if not row or not col then
		row, col = placement.placement_coords(state)
	end
	if not row or not col then
		return
	end
	local cell = state.board[row] and state.board[row][col]
	if not cell or board.is_empty(cell) then
		return
	end
	cell.duration_left = delay_rounds
	duration_left.set_tick_skip_for_placement(state, row, col)
end

--- Enqueue removal when ``duration_left`` is zero after the generic tick decrement.
--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @return nil
function M.expire_at_zero(state, row, col, cell)
	if duration_left.remaining(cell) ~= 0 then
		return
	end
	pending_removals.enqueue(state, {
		row = row,
		col = col,
		reason = "self_destruct_expire",
	})
	duration_left.clear(cell)
end

return M
