--- Defence stone one-shot solidity buffs on connected friendly groups.
--- @module objects.defence_solidity_network

local board = require("board")
local config = require("config")
local stone_params = require("objects.parameters.stones")
local stone_solidity = require("objects.stone_solidity")

local M = {}

local DEFENCE_STONE_ID = "defence_stone"

--- @param row integer
--- @param col integer
--- @return fun(): integer|nil, integer|nil
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
--- @return table[] cells ``{ row, col, cell }``
local function collect_connected_component(b, row, col, color)
	local n = config.BOARD_SIZE
	local visited = {}
	local queue = { { row, col } }
	local head = 1
	local component = {}
	while head <= #queue do
		local r, c = queue[head][1], queue[head][2]
		head = head + 1
		local key = r * (n + 1) + c
		if not visited[key] then
			visited[key] = true
			local cell = b[r][c]
			if not board.is_empty(cell) and cell.color == color then
				component[#component + 1] = { row = r, col = c, cell = cell }
				for nr, nc in each_chebyshev_neighbor(r, c) do
					local neighbor = b[nr][nc]
					if not board.is_empty(neighbor) and neighbor.color == color then
						queue[#queue + 1] = { nr, nc }
					end
				end
			end
		end
	end
	return component
end

--- @param component table[]
--- @return integer
local function count_defence_stones_in_component(component)
	local count = 0
	for i = 1, #component do
		if component[i].cell.kind == DEFENCE_STONE_ID then
			count = count + 1
		end
	end
	return count
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param color integer
--- @return integer
function M.defence_stone_count_in_component(b, row, col, color)
	local component = collect_connected_component(b, row, col, color)
	return count_defence_stones_in_component(component)
end

--- @param cell table
--- @param defence_count integer
--- @return integer
local function bonus_delta_for_cell(cell, defence_count)
	local per_source = stone_params.defence_solidity_bonus
	if defence_count <= 0 then
		return 0
	end
	if cell.kind == DEFENCE_STONE_ID then
		return per_source
	end
	return defence_count * per_source
end

--- @param cell table
--- @param defence_count integer
--- @return nil
local function set_defence_bonus_for_cell(cell, defence_count)
	local target_bonus = bonus_delta_for_cell(cell, defence_count)
	local max_s = stone_solidity.stone_max_solidity(cell.kind)
	local previous_bonus = cell._defence_solidity_bonus or 0
	local current = cell.solidity or max_s
	local intrinsic = current - previous_bonus
	cell._defence_solidity_bonus = target_bonus
	cell.solidity = intrinsic + target_bonus
end

--- One-shot buff for the connected group when a defence stone is played.
--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.apply_on_play(state, row, col)
	local b = state.board
	local cell = b[row] and b[row][col]
	if board.is_empty(cell) then
		return
	end
	local component = collect_connected_component(b, row, col, cell.color)
	local defence_count = count_defence_stones_in_component(component)
	if defence_count <= 0 then
		return
	end
	for i = 1, #component do
		local entry = component[i]
		set_defence_bonus_for_cell(entry.cell, defence_count)
	end
end

--- Shared on-play buff when a non-defence stone joins an existing defence network.
--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.apply_adjacency_on_play(state, row, col)
	local b = state.board
	local cell = b[row] and b[row][col]
	if board.is_empty(cell) or cell.kind == DEFENCE_STONE_ID then
		return
	end
	local defence_count = M.defence_stone_count_in_component(b, row, col, cell.color)
	set_defence_bonus_for_cell(cell, defence_count)
end

return M
