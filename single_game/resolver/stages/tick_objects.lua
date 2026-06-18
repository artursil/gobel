--- Generic end-of-turn ``duration_left`` decrement.
--- @module single_game.resolver.stages.tick_objects

local board = require("board")
local config = require("config")
local duration_left = require("objects.effects_conditions.helpers.shared.duration_left")

local M = {}

--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param key string
--- @return integer|nil row
--- @return integer|nil col
local function parse_cell_key(key)
	local row_s, col_s = key:match("^(%d+):(%d+)$")
	if not row_s or not col_s then
		return nil, nil
	end
	return tonumber(row_s), tonumber(col_s)
end

--- Migrate ``board_cell_timers`` entries onto stone cells as ``duration_left``.
--- @param state table
--- @return nil
local function migrate_board_cell_timers(state)
	if not state.board_cell_timers then
		return
	end
	for key, remaining in pairs(state.board_cell_timers) do
		if type(remaining) == "number" then
			local row, col = parse_cell_key(key)
			if row and col and state.board[row] and state.board[row][col] then
				local cell = state.board[row][col]
				if not board.is_empty(cell) and cell.duration_left == nil then
					cell.duration_left = remaining
				end
			end
		end
	end
end

--- @param state table
--- @param opts table|nil ``{ skip_cell = { row, col }, decrement_board_cell_timers = boolean }``
--- @return nil
function M.decrement(state, opts)
	opts = opts or {}
	local skip = opts.skip_cell
	if opts.decrement_board_cell_timers then
		migrate_board_cell_timers(state)
	end
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			if skip and skip.row == r and skip.col == c then
			else
				local cell = state.board[r][c]
				if not board.is_empty(cell) then
					duration_left.decrement_cell(cell)
				end
			end
		end
	end
end

--- Decrement timers only; does not run side effects.
--- @param state table
--- @param opts table|nil
--- @return nil
function M.run(state, opts)
	M.decrement(state, opts)
end

return M
