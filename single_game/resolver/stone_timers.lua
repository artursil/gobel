--- Clears cell-owned timer fields when stones leave the board.
--- @module single_game.resolver.stone_timers

local board = require("board")
local duration_left = require("objects.effects_conditions.helpers.shared.duration_left")

local M = {}

--- @param state table
--- @return nil
function M.ensure_state(state)
	state.board_cell_timers = state.board_cell_timers or {}
end

--- @param cell table
--- @return nil
local function clear_cell_timer_fields(cell)
	duration_left.clear(cell)
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.clear(state, row, col)
	local cell = state.board[row] and state.board[row][col]
	if cell and not board.is_empty(cell) then
		clear_cell_timer_fields(cell)
	end
	M.ensure_state(state)
	local key = row .. ":" .. col
	state.board_cell_timers[key] = nil
end

--- @param state table
--- @param old_board table
--- @param new_board table
--- @return nil
function M.clear_removed_stones(state, old_board, new_board)
	local config = require("config")
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local old_cell = old_board[r][c]
			local new_cell = new_board[r][c]
			local old_present = not board.is_empty(old_cell)
			local new_present = not board.is_empty(new_cell)
			if old_present and (not new_present or old_cell.kind ~= new_cell.kind or old_cell.color ~= new_cell.color) then
				M.clear(state, r, c)
			end
		end
	end
end

return M
