--- Per-cell territory control streak grid (positive black, negative white).
--- @module resolver.territory_control_rounds

local board = require("board")
local config = require("config")
local stone_params = require("objects.parameters.stones")

local M = {}

--- @return table
function M.new_grid()
	local n = config.BOARD_SIZE
	local grid = {}
	for r = 1, n do
		grid[r] = {}
		for c = 1, n do
			grid[r][c] = 0
		end
	end
	return grid
end

--- @param state table
--- @return nil
function M.ensure_grid(state)
	if state.territory_control_rounds and state.territory_control_rounds[1] then
		return
	end
	local grid = M.new_grid()
	local legacy = state.territory_control_rounds
	if type(legacy) == "table" then
		for key, value in pairs(legacy) do
			if type(key) == "string" then
				local row_s, col_s = key:match("^(%d+):(%d+)$")
				if row_s and col_s then
					grid[tonumber(row_s)][tonumber(col_s)] = value
				end
			end
		end
	end
	state.territory_control_rounds = grid
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return integer
function M.get(state, row, col)
	M.ensure_grid(state)
	return state.territory_control_rounds[row][col] or 0
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param value integer
--- @return nil
function M.set(state, row, col, value)
	M.ensure_grid(state)
	state.territory_control_rounds[row][col] = value
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.clear_cell(state, row, col)
	M.set(state, row, col, 0)
end

--- @param territory_cell any
--- @return "black"|"white"|nil
local function owner_from_territory_cell(territory_cell)
	if territory_cell == config.STONE_BLACK then
		return "black"
	end
	if territory_cell == config.STONE_WHITE then
		return "white"
	end
	return nil
end

--- @param current integer
--- @param owner "black"|"white"|nil
--- @param prev_owner_color integer|nil ``config.STONE_BLACK`` | ``config.STONE_WHITE`` | contested
--- @return integer
local function tick_cell(current, owner, prev_owner_color)
	if not owner then
		return 0
	end
	if owner == "black" then
		if current > 0 then
			return current + 1
		end
		if prev_owner_color == config.STONE_BLACK then
			return 1
		end
		return 0
	end
	if current < 0 then
		return current - 1
	end
	if prev_owner_color == config.STONE_WHITE then
		return -1
	end
	return 0
end

--- @param state table
--- @return nil
local function ensure_last_owner_grid(state)
	if state.territory_control_last_owner and state.territory_control_last_owner[1] then
		return
	end
	state.territory_control_last_owner = M.new_grid()
end

--- Advance streaks for empty cells from ``state.territory`` (call after territory resolve).
--- @param state table
--- @return nil
function M.tick(state)
	M.ensure_grid(state)
	ensure_last_owner_grid(state)
	local territory = state.territory
	if not territory then
		return
	end
	local n = config.BOARD_SIZE
	local b = state.board
	local last_owner = state.territory_control_last_owner
	for r = 1, n do
		for c = 1, n do
			if board.is_empty(b[r][c]) then
				local owner_color = territory[r][c]
				local owner = owner_from_territory_cell(owner_color)
				local current = state.territory_control_rounds[r][c] or 0
				local prev_owner_color = last_owner[r][c]
				if prev_owner_color == 0 then
					prev_owner_color = nil
				end
				state.territory_control_rounds[r][c] = tick_cell(current, owner, prev_owner_color)
				last_owner[r][c] = owner_color or 0
			else
				state.territory_control_rounds[r][c] = 0
				last_owner[r][c] = 0
			end
		end
	end
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.record_placement_streak_snapshot(state, row, col)
	M.ensure_grid(state)
	state.placement_control_streak = M.get(state, row, col)
end

--- Streak captured at the last stone placement before the cell was cleared for occupancy.
--- @param state table
--- @return integer
function M.placement_streak_snapshot(state)
	return state.placement_control_streak or 0
end

--- @return nil
function M.clear_placement_streak_snapshot(state)
	state.placement_control_streak = nil
end

--- @param streak integer
--- @param owner string ``"B"`` | ``"W"``
--- @return integer raw delta before plus_mult floor
local function raw_plus_mult_delta(streak, owner)
	if streak == 0 then
		return 0
	end
	local n = math.abs(streak)
	local mult = stone_params.mult_control_streak_multiplier
	if streak > 0 and owner == config.OWNER_BLACK then
		return mult * n
	end
	if streak < 0 and owner == config.OWNER_WHITE then
		return mult * n
	end
	if streak < 0 and owner == config.OWNER_BLACK then
		return -mult * n
	end
	if streak > 0 and owner == config.OWNER_WHITE then
		return -mult * n
	end
	return 0
end

--- @param streak integer
--- @param state table
--- @param owner string ``"B"`` | ``"W"``
--- @return integer
function M.plus_mult_delta_for_streak(streak, state, owner)
	local raw = raw_plus_mult_delta(streak, owner)
	if raw >= 0 then
		return raw
	end
	local match_state = require("match_state")
	local side = owner == config.OWNER_WHITE and "white" or "black"
	local player = match_state.player_for_color(state, side)
	local current = (player and player.score.plus_mult) or 0
	return math.max(-current, raw)
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param owner string ``"B"`` | ``"W"``
--- @return integer
function M.placement_plus_mult_delta(state, row, col, owner)
	return M.plus_mult_delta_for_streak(M.get(state, row, col), state, owner)
end

return M
