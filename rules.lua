--- Go rule checks: liberties, capture, suicide, and simple ko.

local board = require("board")
local config = require("config")

local M = {}

--- Yields valid in-bounds neighbor coordinates for a point.
--- @param row integer
--- @param col integer
--- @return function
function M.each_neighbor(row, col)
	local n = config.BOARD_SIZE
	local dirs = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
	local k = 0
	return function()
		while k < 4 do
			k = k + 1
			local dr, dc = dirs[k][1], dirs[k][2]
			local nr, nc = row + dr, col + dc
			if nr >= 1 and nr <= n and nc >= 1 and nc <= n then
				return nr, nc
			end
		end
	end
end

--- Collects all stones in the contiguous group containing (row, col).
--- @param b table
--- @param row integer
--- @param col integer
--- @return table list of {row, col}
function M.collect_group(b, row, col)
	local color = b[row][col]
	if color == config.STONE_NONE then
		return {}
	end
	local n = config.BOARD_SIZE
	local visited = {}
	local queue = { { row, col } }
	local head = 1
	local out = {}
	while head <= #queue do
		local r, c = queue[head][1], queue[head][2]
		head = head + 1
		local key = r * (n + 1) + c
		if not visited[key] then
			visited[key] = true
			out[#out + 1] = { r, c }
			for nr, nc in M.each_neighbor(r, c) do
				if b[nr][nc] == color then
					queue[#queue + 1] = { nr, nc }
				end
			end
		end
	end
	return out
end

--- Counts liberties (empty adjacent points) of a group.
--- @param b table
--- @param group table
--- @return integer
function M.liberty_count(b, group)
	local n = config.BOARD_SIZE
	local seen = {}
	local count = 0
	for i = 1, #group do
		local r, c = group[i][1], group[i][2]
		for nr, nc in M.each_neighbor(r, c) do
			if b[nr][nc] == config.STONE_NONE then
				local key = nr * (n + 1) + nc
				if not seen[key] then
					seen[key] = true
					count = count + 1
				end
			end
		end
	end
	return count
end

--- Stable key for a group so the same chain is not processed twice from different seeds.
--- @param grp table
--- @param n integer board size
--- @return integer
local function group_key(grp, n)
	local mr, mc = grp[1][1], grp[1][2]
	for i = 2, #grp do
		local r, c = grp[i][1], grp[i][2]
		if r < mr or (r == mr and c < mc) then
			mr, mc = r, c
		end
	end
	return mr * (n + 1) + mc
end

--- Removes opponent groups adjacent to (row, col) with no liberties.
--- Returns capture count and ko point only when exactly one stone is captured from a singleton group.
--- @param b table
--- @param row integer
--- @param col integer
--- @param player integer
--- @return integer captures
--- @return table|nil ko_coord
function M.remove_opponent_captures(b, row, col, player)
	local opp = board.opponent_stone(player)
	local n = config.BOARD_SIZE
	local seen_group = {}
	local removals = {}
	for nr, nc in M.each_neighbor(row, col) do
		if b[nr][nc] == opp then
			local grp = M.collect_group(b, nr, nc)
			local gk = group_key(grp, n)
			if not seen_group[gk] then
				seen_group[gk] = true
				if M.liberty_count(b, grp) == 0 then
					for j = 1, #grp do
						removals[#removals + 1] = { grp[j][1], grp[j][2] }
					end
				end
			end
		end
	end
	local total = #removals
	local ko_coord = nil
	if total == 1 then
		ko_coord = { removals[1][1], removals[1][2] }
	end
	for i = 1, #removals do
		local r2, c2 = removals[i][1], removals[i][2]
		b[r2][c2] = config.STONE_NONE
	end
	return total, ko_coord
end

--- Returns whether playing at (row, col) is legal, the new board, next ko ban, and prisoners taken.
--- @param b table current board
--- @param row integer
--- @param col integer
--- @param player integer
--- @param ko_ban table|nil forbidden intersection for this move {row, col}
--- @return boolean ok
--- @return table|nil new_board
--- @return table|nil new_ko next player's ko ban or nil
--- @return integer captures number of opponent stones removed
function M.try_play(b, row, col, player, ko_ban)
	local n = config.BOARD_SIZE
	if row < 1 or row > n or col < 1 or col > n then
		return false, nil, nil, 0
	end
	if b[row][col] ~= config.STONE_NONE then
		return false, nil, nil, 0
	end
	if ko_ban and ko_ban[1] == row and ko_ban[2] == col then
		return false, nil, nil, 0
	end
	local trial = board.clone(b)
	trial[row][col] = player
	local captures, ko_coord = M.remove_opponent_captures(trial, row, col, player)
	local my_group = M.collect_group(trial, row, col)
	if M.liberty_count(trial, my_group) == 0 then
		return false, nil, nil, 0
	end
	local new_ko = nil
	if ko_coord then
		new_ko = { ko_coord[1], ko_coord[2] }
	end
	return true, trial, new_ko, captures
end

--- Lists every empty intersection where a play is currently legal.
--- @param b table
--- @param player integer
--- @param ko_ban table|nil
--- @return table array of { row, col }
function M.all_legal_moves(b, player, ko_ban)
	local n = config.BOARD_SIZE
	local out = {}
	for r = 1, n do
		for c = 1, n do
			local ok = select(1, M.try_play(b, r, c, player, ko_ban))
			if ok then
				out[#out + 1] = { r, c }
			end
		end
	end
	return out
end

return M
