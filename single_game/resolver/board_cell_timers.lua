--- Per-cell round timers and timed stone removal (no payout on expiry).
--- @module resolver.board_cell_timers

local board = require("board")
local config = require("config")
local territory_control_rounds = require("single_game.resolver.helpers.territory_control_rounds")

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

--- @param state table
--- @return nil
function M.ensure(state)
	state.board_cell_timers = state.board_cell_timers or {}
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param rounds integer
--- @return nil
function M.register(state, row, col, rounds)
	M.ensure(state)
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

--- Decrement timers once.
--- @param state table
--- @return nil
function M.decrement(state)
	M.ensure(state)
	for key, remaining in pairs(state.board_cell_timers) do
		if remaining > 0 then
			state.board_cell_timers[key] = remaining - 1
		end
	end
end

--- Remove stones whose timers reached zero (no scoring payout).
--- @param state table
--- @return nil
function M.expire(state)
	if not state.board_cell_timers then
		return
	end
	local expired_keys = {}
	for key, remaining in pairs(state.board_cell_timers) do
		if remaining <= 0 then
			expired_keys[#expired_keys + 1] = key
		end
	end
	for i = 1, #expired_keys do
		local key = expired_keys[i]
		state.board_cell_timers[key] = nil
		local row, col = parse_cell_key(key)
		if row and col and state.board[row] and state.board[row][col] then
			local cell = state.board[row][col]
			if not board.is_empty(cell) then
				state.board[row][col] = config.STONE_NONE
				territory_control_rounds.clear_cell(state, row, col)
			end
		end
	end
end

return M
