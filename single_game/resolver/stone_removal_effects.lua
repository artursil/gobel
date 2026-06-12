--- Applies scoring and state hooks when board stones are removed (capture or clearance).
--- @module single_game.resolver.stone_removal_effects

local config = require("config")
local board = require("board")
local match_state = require("match_state")
local stone_params = require("objects.parameters.stones")
local effects_helpers = require("objects.effects_helpers")
local stone_removal = require("single_game.resolver.stone_removal")

local M = {}

--- @param color integer
--- @return string
local function side_from_stone_color(color)
	if color == config.STONE_WHITE then
		return "white"
	end
	return "black"
end

--- @param side string
--- @return string
local function owner_from_side(side)
	if side == "white" then
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- Applies escalating_points_stone capture transfer and clears per-cell bank.
--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param captor_side string|nil ``"black"`` | ``"white"`` actor removing the stone; nil skips enemy transfer
--- @return nil
function M.apply_escalating_points_capture(state, row, col, cell, captor_side)
	if not cell or cell.kind ~= "escalating_points_stone" then
		return
	end
	local bank = effects_helpers.stone_stored_value(state, row, col) or 0
	local stone_side = side_from_stone_color(cell.color)
	state.scores = state.scores or {}
	state.scores.points = state.scores.points or { B = 1, W = 1 }
	if captor_side and stone_side ~= captor_side and bank > 0 then
		local captor_owner = owner_from_side(captor_side)
		local transfer = stone_params.eps_capture_multiplier * bank
		state.scores.points[captor_owner] = state.scores.points[captor_owner] + transfer
		local captor_player = match_state.player_for_color(state, captor_side)
		captor_player.score.points = (captor_player.score.points or 1) + transfer
	end
	effects_helpers.set_stone_stored_value(state, row, col, 0)
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param captor_side string|nil
--- @return nil
function M.on_stone_removed(state, row, col, cell, captor_side)
	if board.is_empty(cell) then
		return
	end
	M.apply_escalating_points_capture(state, row, col, cell, captor_side)
	stone_removal.on_removed(state, row, col, cell, nil)
end

--- Finds stones present on ``old_board`` but absent on ``new_board``.
--- @param old_board table
--- @param new_board table
--- @return table[]
local function removed_stones_between_boards(old_board, new_board)
	local n = #old_board
	local removed = {}
	for row = 1, n do
		for col = 1, n do
			local old_cell = old_board[row][col]
			local new_cell = new_board[row][col]
			if not board.is_empty(old_cell) and board.is_empty(new_cell) then
				removed[#removed + 1] = { row = row, col = col, cell = old_cell }
			elseif not board.is_empty(old_cell) and not board.is_empty(new_cell) then
				if old_cell.color ~= new_cell.color or old_cell.kind ~= new_cell.kind then
					removed[#removed + 1] = { row = row, col = col, cell = old_cell }
				end
			end
		end
	end
	return removed
end

--- Runs removal hooks for every stone cleared by a board replacement.
--- @param state table
--- @param old_board table
--- @param new_board table
--- @param captor_side string|nil
--- @return nil
function M.apply_for_board_replacement(state, old_board, new_board, captor_side)
	local removed = removed_stones_between_boards(old_board, new_board)
	for i = 1, #removed do
		local entry = removed[i]
		M.on_stone_removed(state, entry.row, entry.col, entry.cell, captor_side)
	end
end

return M
