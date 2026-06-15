--- Escalating points stone bank init, growth, and capture transfer.
--- @module objects.helper_effects.escalating_points

local board = require("board")
local config = require("config")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_helpers")

local M = {}

--- @param state table
--- @param row integer|nil
--- @param col integer|nil
--- @return nil
function M.init_bank(state, row, col)
	if row == nil or col == nil then
		row, col = helpers.placement_coords(state)
	end
	if row == nil or col == nil then
		return
	end
	helpers.set_stone_stored_value(state, row, col, 0)
end

--- @param state table
--- @param owner string
--- @param row integer
--- @param col integer
--- @param round_points number
--- @return nil
function M.apply_end_of_turn_bank(state, owner, row, col, round_points)
	if state._suppress_recurring_end_of_turn then
		return
	end
	local cell = state.board[row] and state.board[row][col]
	if not cell or board.is_empty(cell) or cell.kind ~= "escalating_points_stone" then
		return
	end
	local stone_owner = cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
	if stone_owner ~= owner then
		return
	end
	local bank = helpers.stone_stored_value(state, row, col) or 0
	local next_bank = bank + round_points
	helpers.set_stone_stored_value(state, row, col, next_bank)
	state.scores.points[owner] = state.scores.points[owner] + round_points
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param opts table|nil
--- @return nil
function M.apply_capture_transfer(state, row, col, cell, opts)
	if not cell or cell.kind ~= "escalating_points_stone" then
		return
	end
	local captor_side = opts and opts.capturer or nil
	local bank = (cell and cell.stored_value) or helpers.stone_stored_value(state, row, col) or 0
	local stone_side = cell.color == config.STONE_WHITE and "white" or "black"
	state.scores = state.scores or {}
	state.scores.points = state.scores.points or { B = 1, W = 1 }
	if captor_side and stone_side ~= captor_side and bank > 0 then
		local captor_owner = captor_side == "white" and config.OWNER_WHITE or config.OWNER_BLACK
		local transfer = stone_params.eps_capture_multiplier * bank
		state.scores.points[captor_owner] = state.scores.points[captor_owner] + transfer
		local captor_player = require("match_state").player_for_color(state, captor_side)
		captor_player.score.points = (captor_player.score.points or 1) + transfer
	end
	helpers.set_stone_stored_value(state, row, col, 0)
end

return M
