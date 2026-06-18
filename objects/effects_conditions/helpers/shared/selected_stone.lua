--- Selected stone targeting helpers for card effects.
--- @module objects.effects_conditions.helpers.shared.selected_stone

local board = require("board")
local queries = require("single_game.resolver.helpers.state_queries")

local M = {}

--- Selected target with row and col, or nil when absent.
function M.target_with_coords(state)
	local target = queries.selected_target(state)
	if not target or target.row == nil or target.col == nil then
		return nil
	end
	return target
end

--- First entry from selected_targets, if any.
function M.first_target(state)
	local targets = queries.selected_targets(state)
	if not targets or #targets == 0 then
		return nil
	end
	return targets[1]
end

--- Row, col, and cell for the selected stone target, or nil when absent or not a stone.
function M.selected_stone_cell(state)
	local target = M.first_target(state) or queries.selected_target(state)
	if not target or target.object_type ~= "stone" then
		return nil, nil, nil
	end
	local row = target.row
	local col = target.col
	local row_cells = state.board and state.board[row]
	if not row_cells then
		return nil, nil, nil
	end
	local cell = row_cells[col]
	if board.is_empty(cell) then
		return nil, nil, nil
	end
	return row, col, cell
end

return M
