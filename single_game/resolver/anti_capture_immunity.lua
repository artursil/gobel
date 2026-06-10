--- Temporary capture immunity for ``anti_capture_stone`` placements.
--- @module resolver.anti_capture_immunity

local board = require("board")
local config = require("config")
local rules = require("rules")
local stone_params = require("objects.parameters.stones")

local M = {}

local data_by_state = setmetatable({}, { __mode = "k" })

--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param key string
--- @return boolean
local function is_cell_timer_key(key)
	return type(key) == "string" and key:find(":", 1, true) ~= nil
end

--- @param state table
--- @return table
local function data_for(state)
	local data = data_by_state[state]
	if not data then
		data = {}
		data_by_state[state] = data
	end
	return data
end

--- @param state table
--- @return table
function M.ensure_map(state)
	if state.stone_immunity_remaining and getmetatable(state.stone_immunity_remaining) then
		return state.stone_immunity_remaining
	end
	local data = data_for(state)
	if state.stone_immunity_remaining then
		for key, remaining in pairs(state.stone_immunity_remaining) do
			if is_cell_timer_key(key) then
				data[key] = remaining
			end
		end
	end
	local map = {}
	setmetatable(map, {
		__index = function(_, key)
			if not is_cell_timer_key(key) then
				return nil
			end
			M.ensure_materialized_from_board(state)
			return data[key]
		end,
		__newindex = function(_, key, value)
			data[key] = value
		end,
	})
	state.stone_immunity_remaining = map
	return map
end

--- @param state table
--- @param board_snapshot table
--- @param row integer
--- @param col integer
--- @param duration integer
--- @return nil
function M.grant_group_immunity(state, board_snapshot, row, col, duration)
	M.ensure_map(state)
	local data = data_for(state)
	local group = rules.collect_group(board_snapshot, row, col)
	for i = 1, #group do
		local r, c = group[i][1], group[i][2]
		data[cell_key(r, c)] = duration
	end
end

--- @param state table
--- @param board_snapshot table|nil
--- @param row integer
--- @param col integer
--- @return nil
function M.grant_at_placement(state, board_snapshot, row, col)
	state._anti_capture_board_snapshot_seeded = true
	M.grant_group_immunity(
		state,
		board_snapshot or state.board,
		row,
		col,
		stone_params.anti_capture_duration_rounds
	)
end

--- Materializes immunity for ``set_board`` layouts that already contain ``anti_capture_stone``.
--- @param state table
--- @return nil
function M.ensure_materialized_from_board(state)
	if state._anti_capture_board_snapshot_seeded then
		return
	end
	local n = config.BOARD_SIZE
	local triggers = {}
	for r = 1, n do
		for c = 1, n do
			local cell = state.board[r][c]
			if not board.is_empty(cell) and cell.kind == "anti_capture_stone" then
				triggers[#triggers + 1] = { r, c }
			end
		end
	end
	if #triggers == 0 then
		return
	end
	state._anti_capture_board_snapshot_seeded = true
	for i = 1, #triggers do
		local r, c = triggers[i][1], triggers[i][2]
		M.grant_group_immunity(state, state.board, r, c, stone_params.anti_capture_duration_rounds)
	end
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return integer
function M.remaining(state, row, col)
	M.ensure_materialized_from_board(state)
	local data = data_for(state)
	return data[cell_key(row, col)] or 0
end

--- @param state table
--- @return nil
function M.tick(state)
	M.ensure_materialized_from_board(state)
	local data = data_for(state)
	local expired = {}
	for key, remaining in pairs(data) do
		if is_cell_timer_key(key) and remaining > 0 then
			local next_remaining = remaining - 1
			if next_remaining <= 0 then
				expired[#expired + 1] = key
			else
				data[key] = next_remaining
			end
		end
	end
	for i = 1, #expired do
		data[expired[i]] = nil
	end
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param player integer
--- @param stone_kind string
--- @return boolean
function M.move_would_capture_immune_group(state, row, col, player, stone_kind)
	M.ensure_materialized_from_board(state)
	local stone_solidity = require("objects.stone_solidity")
	local trial = board.clone(state.board)
	trial[row][col] = board.make_stone(
		player,
		stone_kind,
		stone_solidity.stone_max_solidity(stone_kind),
		nil
	)
	local opp = board.opponent_stone(player)
	local n = config.BOARD_SIZE
	local seen_group = {}
	for nr, nc in rules.each_neighbor(row, col) do
		if board.chain_color(trial[nr][nc]) == opp then
			local grp = rules.collect_group(trial, nr, nc)
			local gk = grp[1][1] * (n + 1) + grp[1][2]
			if not seen_group[gk] then
				seen_group[gk] = true
				if rules.liberty_count(trial, grp) == 0 then
					for j = 1, #grp do
						local r2, c2 = grp[j][1], grp[j][2]
						if M.remaining(state, r2, c2) > 0 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end

return M
