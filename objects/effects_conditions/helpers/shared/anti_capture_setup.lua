--- Anti-capture immunity setup: grants ``duration_left`` on the placed connected group.
--- @module objects.effects_conditions.helpers.shared.anti_capture_setup

local board = require("board")
local rules = require("rules")
local placement = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

--- @param board_snapshot table
--- @param row integer
--- @param col integer
--- @param duration integer
--- @return nil
function M.grant_group_on_cells(board_snapshot, row, col, duration)
	local group = rules.collect_group(board_snapshot, row, col)
	for i = 1, #group do
		local r, c = group[i][1], group[i][2]
		local cell = board_snapshot[r][c]
		if cell and not board.is_empty(cell) then
			cell.duration_left = duration
		end
	end
end

--- @param state table
--- @param duration integer
--- @return nil
function M.apply_on_play(state, duration)
	local row, col = placement.placement_coords(state)
	if not row or not col then
		return
	end
	state._anti_capture_board_snapshot_seeded = true
	M.grant_group_on_cells(state.board, row, col, duration)
end

return M
