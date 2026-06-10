--- Per-cell stone runtime counters (e.g. escalating money received totals).
--- @module single_game.resolver.stone_stored_values

local board = require("board")
local config = require("config")

local M = {}

--- @param row integer
--- @param col integer
--- @return string
function M.cell_key(row, col)
	return row .. ":" .. col
end

--- @param state table
--- @return table
function M.ensure_bag(state)
	local bag = state.stone_stored_values
	if not bag then
		bag = {}
		state.stone_stored_values = bag
	end
	if not getmetatable(bag) then
		setmetatable(bag, {
			--- Cleared or never-set cells read as zero for resolver-visible totals.
			--- @param _ table
			--- @param _key string
			--- @return number
			__index = function(_, _key)
				return 0
			end,
		})
	end
	return bag
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return number
function M.get(state, row, col)
	local cell = state.board and state.board[row] and state.board[row][col]
	if type(cell) == "table" and cell.stored_value ~= nil then
		return cell.stored_value
	end
	local bag = M.ensure_bag(state)
	return bag[M.cell_key(row, col)] or 0
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param value number
--- @return nil
function M.set(state, row, col, value)
	M.ensure_bag(state)[M.cell_key(row, col)] = value
	local row_cells = state.board and state.board[row]
	if not row_cells then
		return
	end
	local cell = row_cells[col]
	if type(cell) == "table" and not board.is_empty(cell) then
		cell.stored_value = value
	end
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.clear(state, row, col)
	local key = M.cell_key(row, col)
	M.ensure_bag(state)[key] = 0
end

--- @param state table
--- @param color integer
--- @return integer
function M.count_stones_for_color(state, color)
	local n = config.BOARD_SIZE
	local count = 0
	for r = 1, n do
		for c = 1, n do
			local cell = state.board[r][c]
			if not board.is_empty(cell) and cell.color == color then
				count = count + 1
			end
		end
	end
	return count
end

return M
