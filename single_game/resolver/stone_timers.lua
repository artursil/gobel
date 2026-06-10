--- Board cell survival timers for delayed stone effects (e.g. delay_reward_stone).
--- @module single_game.resolver.stone_timers

local board = require("board")
local config = require("config")
local stone_params = require("objects.parameters.stones")

local M = {}

--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param state table
--- @return nil
function M.ensure_state(state)
	state.board_cell_timers = state.board_cell_timers or {}
	state.stone_timer_meta = state.stone_timer_meta or {}
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.clear(state, row, col)
	M.ensure_state(state)
	local key = cell_key(row, col)
	state.board_cell_timers[key] = nil
	state.stone_timer_meta[key] = nil
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return integer
function M.remaining(state, row, col)
	M.ensure_state(state)
	local key = cell_key(row, col)
	return state.board_cell_timers[key] or 0
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param rounds integer
--- @param owner string ``config.OWNER_BLACK`` | ``config.OWNER_WHITE``
--- @param timer_kind string
--- @param meta table|nil
--- @return nil
function M.register(state, row, col, rounds, owner, timer_kind, meta)
	M.ensure_state(state)
	local key = cell_key(row, col)
	state.board_cell_timers[key] = rounds
	state.stone_timer_meta[key] = {
		owner = owner,
		kind = timer_kind,
		meta = meta or {},
	}
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param owner string
--- @param rounds integer|nil
--- @param payout integer|nil
--- @return nil
function M.register_delay_reward(state, row, col, owner, rounds, payout)
	M.register(
		state,
		row,
		col,
		rounds or stone_params.points_delay_rounds,
		owner,
		"delay_reward_survival",
		{ payout = payout or stone_params.points_delay_payout }
	)
end

--- @param state table
--- @param skip_placement_turn boolean when true, survival timers do not tick this turn advance
--- @return nil
function M.tick_on_turn_advance(state, skip_placement_turn)
	if skip_placement_turn then
		return
	end
	M.ensure_state(state)
	for key, remaining in pairs(state.board_cell_timers) do
		if remaining > 0 then
			state.board_cell_timers[key] = remaining - 1
		end
	end
end

--- @param state table
--- @param old_board table
--- @param new_board table
--- @return nil
function M.clear_removed_stones(state, old_board, new_board)
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

--- @param state table
--- @return nil
function M.process_expirations(state)
	if state.ended or state.over then
		return
	end
	M.ensure_state(state)
	state.scores = state.scores or {}
	state.scores.points = state.scores.points or { B = 1, W = 1 }
	for key, remaining in pairs(state.board_cell_timers) do
		if remaining == 0 then
			local row_s, col_s = key:match("^(%d+):(%d+)$")
			if row_s and col_s then
				local row = tonumber(row_s)
				local col = tonumber(col_s)
				local meta_entry = state.stone_timer_meta[key]
				local cell = state.board[row] and state.board[row][col]
				if meta_entry and not board.is_empty(cell) then
					if meta_entry.kind == "delay_reward_survival" then
						local payout = meta_entry.meta.payout or stone_params.points_delay_payout
						local owner = meta_entry.owner
						if owner and payout > 0 then
							state.scores.points[owner] = (state.scores.points[owner] or 1) + payout
						end
					end
				end
				M.clear(state, row, col)
			end
		end
	end
end

return M
