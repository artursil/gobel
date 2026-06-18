--- Delay-reward stone setup and end-of-turn payout when the timer expires.
--- @module objects.effects_conditions.helpers.shared.delay_reward

local board = require("board")
local config = require("config")
local duration_left = require("objects.effects_conditions.helpers.shared.duration_left")
local placement = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

--- @param state table
--- @param row integer
--- @param col integer
--- @param rounds integer
--- @param payout number
--- @return nil
function M.setup(state, row, col, rounds, payout)
	local cell = state.board[row] and state.board[row][col]
	if not cell or board.is_empty(cell) then
		return
	end
	cell.duration_left = rounds
	cell.delay_payout = payout
	duration_left.set_tick_skip_for_placement(state, row, col)
end

--- Pay stored payout when ``duration_left`` reached zero after the generic tick decrement.
--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @return nil
function M.payout_at_zero(state, row, col, cell)
	if duration_left.remaining(cell) ~= 0 then
		return
	end
	if cell.delay_payout == nil then
		return
	end
	local payout_amount = cell.delay_payout
	cell.delay_payout = nil
	duration_left.clear(cell)
	if board.is_empty(cell) or payout_amount <= 0 then
		return
	end
	local owner = cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
	state.scores.points[owner] = state.scores.points[owner] + payout_amount
end

--- @param state table
--- @param owner string
--- @param rounds integer
--- @param payout number
--- @param row integer|nil
--- @param col integer|nil
--- @return nil
function M.setup_from_placement(state, owner, rounds, payout, row, col)
	if not row or not col then
		row, col = placement.placement_coords(state)
	end
	if not row or not col then
		return
	end
	M.setup(state, row, col, rounds, payout)
end

return M
