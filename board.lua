--- Board grid: empty cells vs stone records (color + kind) for extensible piece types.

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

--- Copies runtime stone metadata that is not part of the static definition snapshot.
--- @param source table
--- @param target table
--- @return nil
local function copy_stone_runtime_fields(source, target)
	if source._defence_solidity_bonus ~= nil then
		target._defence_solidity_bonus = source._defence_solidity_bonus
	end
	if source.survival_rounds_remaining ~= nil then
		target.survival_rounds_remaining = source.survival_rounds_remaining
	end
	if source.timer_remaining_rounds ~= nil then
		target.timer_remaining_rounds = source.timer_remaining_rounds
	end
	if source.delay_payout ~= nil then
		target.delay_payout = source.delay_payout
	end
	if source.immunity_remaining ~= nil then
		target.immunity_remaining = source.immunity_remaining
	end
end

--- Allocates a stone value for placement on the board.
--- @param color integer
--- @param kind string
--- @param solidity integer|nil current health; nil = max for ``kind``
--- @param level integer|nil upgrade tier snapshot for this board cell
--- @return table
function M.make_stone(color, kind, solidity, level)
	local stone_solidity = require("objects.stone_solidity")
	local s = solidity
	if s == nil then
		s = stone_solidity.stone_max_solidity(kind)
	end
	local cell = { color = color, kind = kind, solidity = s }
	if level ~= nil then
		cell.level = level
	end
	return cell
end

--- True if the cell holds no stone.
--- @param cell any
--- @return boolean
function M.is_empty(cell)
	return cell == nil or cell == config.STONE_NONE
end

--- Returns the chain color used for liberties and capture, or STONE_NONE if empty.
--- @param cell any
--- @return integer
function M.chain_color(cell)
	if M.is_empty(cell) then
		return config.STONE_NONE
	end
	return cell.color
end

--- True if both cells are stones of the same chain color.
--- @param a any
--- @param b any
--- @return boolean
function M.same_chain_color(a, b)
	if M.is_empty(a) or M.is_empty(b) then
		return false
	end
	return a.color == b.color
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
			local cell = board[r][c]
			if M.is_empty(cell) then
				copy[r][c] = config.STONE_NONE
			else
				copy[r][c] = M.make_stone(cell.color, cell.kind, cell.solidity, cell.level)
				copy_stone_runtime_fields(cell, copy[r][c])
			end
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
			local x, y = a[r][c], b[r][c]
			if M.is_empty(x) and M.is_empty(y) then
			elseif M.is_empty(x) or M.is_empty(y) then
				return false
			elseif x.color ~= y.color or x.kind ~= y.kind then
				return false
			else
				local stone_solidity = require("objects.stone_solidity")
				local sx = x.solidity or stone_solidity.stone_max_solidity(x.kind)
				local sy = y.solidity or stone_solidity.stone_max_solidity(y.kind)
				if sx ~= sy then
					return false
				end
			end
		end
	end
	return true
end

--- Returns the opposite chain color for a player color.
--- @param stone integer
--- @return integer
function M.opponent_stone(stone)
	if stone == config.STONE_BLACK then
		return config.STONE_WHITE
	end
	return config.STONE_BLACK
end

return M
