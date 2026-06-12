--- Defence stone solidity network: recompute board solidity from connected defence sources.
--- @module objects.defence_solidity_network

local board = require("board")
local config = require("config")
local stone_params = require("objects.parameters.stones")
local stone_solidity = require("objects.stone_solidity")

local M = {}

local DEFENCE_STONE_ID = "defence_stone"

--- @param row integer
--- @param col integer
--- @return function
local function each_chebyshev_neighbor(row, col)
	local n = config.BOARD_SIZE
	local dirs = {
		{ -1, -1 },
		{ -1, 0 },
		{ -1, 1 },
		{ 0, -1 },
		{ 0, 1 },
		{ 1, -1 },
		{ 1, 0 },
		{ 1, 1 },
	}
	local index = 0
	return function()
		while index < #dirs do
			index = index + 1
			local dr, dc = dirs[index][1], dirs[index][2]
			local nr, nc = row + dr, col + dc
			if nr >= 1 and nr <= n and nc >= 1 and nc <= n then
				return nr, nc
			end
		end
	end
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param color integer
--- @return integer defence_stone_count
local function count_defence_stones_in_component(b, row, col, color)
	local n = config.BOARD_SIZE
	local visited = {}
	local queue = { { row, col } }
	local head = 1
	local defence_count = 0
	while head <= #queue do
		local r, c = queue[head][1], queue[head][2]
		head = head + 1
		local key = r * (n + 1) + c
		if not visited[key] then
			visited[key] = true
			local cell = b[r][c]
			if not board.is_empty(cell) and cell.color == color then
				if cell.kind == DEFENCE_STONE_ID then
					defence_count = defence_count + 1
				end
				for nr, nc in each_chebyshev_neighbor(r, c) do
					local neighbor = b[nr][nc]
					if not board.is_empty(neighbor) and neighbor.color == color then
						queue[#queue + 1] = { nr, nc }
					end
				end
			end
		end
	end
	return defence_count
end

--- @param b table
--- @param row integer
--- @param col integer
--- @return integer
function M.defence_solidity_bonus_for_cell(b, row, col)
	local cell = b[row][col]
	if board.is_empty(cell) then
		return 0
	end
	local defence_count = count_defence_stones_in_component(b, row, col, cell.color)
	if defence_count == 0 then
		return 0
	end
	local per_source = stone_params.defence_solidity_bonus
	if cell.kind == DEFENCE_STONE_ID then
		return per_source
	end
	return defence_count * per_source
end

--- Reapply defence bonuses on every occupied cell after board connectivity changes.
--- @param state table
--- @return nil
function M.apply(state)
	M.recompute_board(state.board)
end

--- @param b table
--- @return nil
function M.recompute_board(b)
	local n = config.BOARD_SIZE
	for row = 1, n do
		for col = 1, n do
			local cell = b[row][col]
			if not board.is_empty(cell) then
				local previous_bonus = cell._defence_solidity_bonus or 0
				local max_s = stone_solidity.stone_max_solidity(cell.kind)
				local current = cell.solidity or max_s
				local intrinsic = current - previous_bonus
				local new_bonus = M.defence_solidity_bonus_for_cell(b, row, col)
				cell._defence_solidity_bonus = new_bonus
				cell.solidity = intrinsic + new_bonus
			end
		end
	end
end

return M
