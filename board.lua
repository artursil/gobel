--- Board grid helpers: allocation, cloning, and stone queries.

local config = require("config")

local M = {}

--- Creates an empty square board of configured size.
--- @return table
function M.new()
	local n = config.BOARD_SIZE
	local b = {}
	for r = 1, n do
		b[r] = {}
		for c = 1, n do
			b[r][c] = config.STONE_NONE
		end
	end
	return b
end

--- Returns a deep copy of the board for rule simulation.
--- @param board table
--- @return table
function M.clone(board)
	local n = config.BOARD_SIZE
	local copy = {}
	for r = 1, n do
		copy[r] = {}
		for c = 1, n do
			copy[r][c] = board[r][c]
		end
	end
	return copy
end

--- Returns whether two boards are identical.
--- @param a table
--- @param b table
--- @return boolean
function M.equal(a, b)
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			if a[r][c] ~= b[r][c] then
				return false
			end
		end
	end
	return true
end

--- Returns the opposite stone color for a non-empty stone.
--- @param stone integer
--- @return integer
function M.opponent_stone(stone)
	if stone == config.STONE_BLACK then
		return config.STONE_WHITE
	end
	return config.STONE_BLACK
end

return M
