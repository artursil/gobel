--- Per-cell round timers (legacy register; prefer ``cell.duration_left`` from timed setup effects).
--- @module resolver.board_cell_timers

local M = {}

--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param rounds integer
--- @return nil
function M.register(state, row, col, rounds)
	state.board_cell_timers = state.board_cell_timers or {}
	local cell = state.board[row] and state.board[row][col]
	if cell and cell.duration_left == nil then
		cell.duration_left = rounds
	end
	state.board_cell_timers[cell_key(row, col)] = rounds
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.clear(state, row, col)
	if not state.board_cell_timers then
		return
	end
	state.board_cell_timers[cell_key(row, col)] = nil
end

return M
