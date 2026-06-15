--- Temporary capture immunity for the placed stone and its orthogonally connected own group.
--- @module objects.helper_effects.anti_capture_immunity

local board = require("board")
local rules = require("rules")

local M = {}

--- @param board_snapshot table
--- @param row integer
--- @param col integer
--- @param duration integer
--- @return nil
function M.grant_group_immunity_on_cells(board_snapshot, row, col, duration)
	local group = rules.collect_group(board_snapshot, row, col)
	for i = 1, #group do
		local r, c = group[i][1], group[i][2]
		local cell = board_snapshot[r][c]
		if cell and not board.is_empty(cell) then
			cell.immunity_remaining = duration
		end
	end
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param duration integer
--- @return nil
function M.apply(state, row, col, duration)
	if row == nil or col == nil then
		return
	end
	state._anti_capture_board_snapshot_seeded = true
	M.grant_group_immunity_on_cells(state.board, row, col, duration)
end

--- @param cell table
--- @return nil
function M.tick_cell(cell)
	local remaining = cell.immunity_remaining
	if type(remaining) ~= "number" or remaining <= 0 then
		return
	end
	remaining = remaining - 1
	if remaining <= 0 then
		cell.immunity_remaining = nil
		return
	end
	cell.immunity_remaining = remaining
end

return M
