--- Pattern-completion proximity for X/+ shapes (no ``resolve_round``).
--- @module ai.heuristics.pattern_proximity

local board = require("board")
local config = require("config")
local shape_patterns = require("game.patterns.shape_patterns")

local M = {}

local MAX_MOVES_DEFAULT = 2

local DIAG_DIRS = {
	{ -1, -1 },
	{ -1, 1 },
	{ 1, -1 },
	{ 1, 1 },
}

local ORTHO_DIRS = {
	{ -1, 0 },
	{ 1, 0 },
	{ 0, -1 },
	{ 0, 1 },
}

--- @param b table
--- @param r integer
--- @param c integer
--- @return boolean
local function in_bounds(r, c)
	local n = config.BOARD_SIZE
	return r >= 1 and r <= n and c >= 1 and c <= n
end

--- @param b table
--- @param r integer
--- @param c integer
--- @param color integer
--- @return boolean
local function matches(b, r, c, color)
	if not in_bounds(r, c) then
		return false
	end
	local cell = b[r][c]
	return not board.is_empty(cell) and cell.color == color
end

--- @param b table
--- @param cr integer
--- @param cc integer
--- @param color integer
--- @return boolean
local function x_core_complete(b, cr, cc, color)
	for i = 1, #DIAG_DIRS do
		local dr, dc = DIAG_DIRS[i][1], DIAG_DIRS[i][2]
		if not matches(b, cr + dr, cc + dc, color) then
			return false
		end
	end
	return matches(b, cr, cc, color)
end

--- @param b table
--- @param cr integer
--- @param cc integer
--- @param color integer
--- @return boolean
local function plus_core_complete(b, cr, cc, color)
	for i = 1, #ORTHO_DIRS do
		local dr, dc = ORTHO_DIRS[i][1], ORTHO_DIRS[i][2]
		if not matches(b, cr + dr, cc + dc, color) then
			return false
		end
	end
	return matches(b, cr, cc, color)
end

--- @param b table
--- @param r integer
--- @param c integer
--- @param color integer
--- @return integer 0 own, 1 empty needed, 2 blocked by opponent
local function arm_status(b, r, c, color)
	if not in_bounds(r, c) then
		return 2
	end
	local cell = b[r][c]
	if board.is_empty(cell) then
		return 1
	end
	if cell.color == color then
		return 0
	end
	return 2
end

--- @param b table
--- @param cr integer
--- @param cc integer
--- @param color integer
--- @param dirs table[]
--- @return integer missing count to complete minimal cross (excluding center)
local function missing_for_cross(b, cr, cc, color, dirs)
	if matches(b, cr, cc, color) then
		local missing = 0
		for i = 1, #dirs do
			local dr, dc = dirs[i][1], dirs[i][2]
			local status = arm_status(b, cr + dr, cc + dc, color)
			if status == 1 then
				missing = missing + 1
			elseif status == 2 then
				missing = missing + 2
			end
		end
		return missing
	end
	local best = 5
	for i = 1, #dirs do
		local dr, dc = dirs[i][1], dirs[i][2]
		if not matches(b, cr + dr, cc + dc, color) then
			local missing = 1
			for j = 1, #dirs do
				if j ~= i then
					local dr2, dc2 = dirs[j][1], dirs[j][2]
					if not matches(b, cr + dr2, cc + dc2, color) then
						missing = missing + 1
					end
				end
			end
			if missing < best then
				best = missing
			end
		end
	end
	return best
end

--- @param b table
--- @param color integer
--- @param dirs table[]
--- @param core_fn function
--- @param max_moves integer
--- @return integer minimum empty plays to complete any cross
function M.moves_to_complete_cross(b, color, dirs, core_fn, max_moves)
	local n = config.BOARD_SIZE
	local best = max_moves + 1
	for cr = 2, n - 1 do
		for cc = 2, n - 1 do
			if core_fn(b, cr, cc, color) then
				return 0
			end
			local missing = missing_for_cross(b, cr, cc, color, dirs)
			if missing <= max_moves and missing < best then
				best = missing
			end
		end
	end
	if best > max_moves then
		return max_moves + 1
	end
	return best
end

--- @param b table
--- @param color integer
--- @param max_moves integer|nil
--- @return integer
function M.moves_to_complete_x(b, color, max_moves)
	local cap = max_moves or MAX_MOVES_DEFAULT
	return M.moves_to_complete_cross(b, color, DIAG_DIRS, x_core_complete, cap)
end

--- @param b table
--- @param color integer
--- @param max_moves integer|nil
--- @return integer
function M.moves_to_complete_plus(b, color, max_moves)
	local cap = max_moves or MAX_MOVES_DEFAULT
	return M.moves_to_complete_cross(b, color, ORTHO_DIRS, plus_core_complete, cap)
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param color integer
--- @param pattern "x"|"plus"
--- @param max_moves integer|nil
--- @return boolean
function M.is_blocking_cell(b, row, col, opponent_color, pattern, max_moves)
	if not board.is_empty(b[row][col]) then
		return false
	end
	local cap = max_moves or MAX_MOVES_DEFAULT
	local dirs = pattern == "plus" and ORTHO_DIRS or DIAG_DIRS
	local core_fn = pattern == "plus" and plus_core_complete or x_core_complete
	local before = M.moves_to_complete_cross(b, opponent_color, dirs, core_fn, cap)
	if before > cap then
		return false
	end
	local blocker = opponent_color == config.STONE_BLACK and config.STONE_WHITE or config.STONE_BLACK
	local trial = board.clone(b)
	trial[row][col] = board.make_stone(blocker, "stone_basic")
	local after = M.moves_to_complete_cross(trial, opponent_color, dirs, core_fn, cap)
	return after > cap or after > before
end

return M
