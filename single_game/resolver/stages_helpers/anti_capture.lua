--- Anti-capture legality helpers (reads ``cell.duration_left``).
--- @module single_game.resolver.stages_helpers.anti_capture

local board = require("board")
local config = require("config")
local rules = require("rules")
local stone_params = require("objects.parameters.stones")
local duration_left = require("objects.effects_conditions.helpers.shared.duration_left")
local anti_capture_setup = require("objects.effects_conditions.helpers.shared.anti_capture_setup")

local M = {}

--- Materializes ``duration_left`` for test boards with pre-placed anti_capture stones.
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
		state._anti_capture_board_snapshot_seeded = true
		return
	end
	state._anti_capture_board_snapshot_seeded = true
	local immunity_duration = stone_params.anti_capture_duration_rounds
	for i = 1, #triggers do
		local r, c = triggers[i][1], triggers[i][2]
		anti_capture_setup.grant_group_on_cells(state.board, r, c, immunity_duration)
	end
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return integer
function M.remaining(state, row, col)
	M.ensure_materialized_from_board(state)
	local cell = state.board[row] and state.board[row][col]
	if not cell or board.is_empty(cell) then
		return 0
	end
	return duration_left.remaining(cell)
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

--- @param state table
--- @param side string ``"black"`` | ``"white"``
--- @param moves table[] ``{ row, col }`` or ``{ r, c }``
--- @param stone_id string
--- @return table[]
function M.filter_legal_moves(state, side, moves, stone_id)
	local player = side == "white" and config.STONE_WHITE or config.STONE_BLACK
	local out = {}
	for i = 1, #moves do
		local move = moves[i]
		local row = move.row or move[1] or move.r
		local col = move.col or move[2] or move.c
		if row and col and not M.move_would_capture_immune_group(state, row, col, player, stone_id) then
			out[#out + 1] = move
		end
	end
	return out
end

return M
