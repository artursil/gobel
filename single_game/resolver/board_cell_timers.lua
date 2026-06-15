--- Per-cell round timers for self-destruct stones (register/clear only; tick via ``tick_objects``).
--- @module resolver.board_cell_timers

local M = {}
--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param state table--- @return nil
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

--- Decrement timers once (delegates to ``tick_objects``).
--- @param state table
--- @return nil
function M.decrement(state)
	local tick_objects = require("single_game.resolver.stages.tick_objects")
	tick_objects.decrement(state, { decrement_board_cell_timers = true })
end

--- Remove stones whose timers reached zero (delegates to ``tick_objects``).
--- @param state table
--- @return nil
function M.expire(state)
	local tick_objects = require("single_game.resolver.stages.tick_objects")
	tick_objects.remove_expired_timed_stones(state)
end
return M
