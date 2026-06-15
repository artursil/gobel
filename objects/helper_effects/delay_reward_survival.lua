--- Delayed payout after ``survival_rounds_remaining`` on the stone cell reaches zero.
--- @module objects.helper_effects.delay_reward_survival

local board = require("board")
local config = require("config")
local helpers = require("objects.effects_helpers")

local M = {}

--- @param state table
--- @param row integer
--- @param col integer
--- @param rounds integer
--- @param payout number
--- @return nil
function M.apply_placement(state, row, col, rounds, payout)
	local cell = state.board[row] and state.board[row][col]
	if not cell or board.is_empty(cell) then
		return
	end
	cell.survival_rounds_remaining = rounds
	cell.delay_payout = payout
	cell.timer_remaining_rounds = rounds
	state._effect_tick_skip_cell = { row = row, col = col }
end

--- @param cell table
--- @param default_payout number
--- @return nil
function M.tick_cell(cell, default_payout)
	local remaining = cell.survival_rounds_remaining
	if type(remaining) ~= "number" or remaining <= 0 then
		return
	end
	remaining = remaining - 1
	cell.survival_rounds_remaining = remaining
	cell.timer_remaining_rounds = remaining > 0 and remaining or nil
	if remaining > 0 then
		return
	end
	cell.survival_rounds_remaining = nil
	cell.timer_remaining_rounds = nil
	local payout_amount = cell.delay_payout or default_payout
	cell.delay_payout = nil
	if board.is_empty(cell) or payout_amount <= 0 then
		return
	end
	return payout_amount, cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
end

--- @param state table
--- @param owner string
--- @param payout_amount number
--- @return nil
function M.apply_payout(state, owner, payout_amount)
	state.scores = state.scores or {}
	state.scores.points = state.scores.points or { B = 1, W = 1 }
	state.scores.points[owner] = (state.scores.points[owner] or 1) + payout_amount
end

--- @param state table
--- @param row integer|nil
--- @param col integer|nil
--- @param rounds integer
--- @param payout number
--- @param effect_def table|nil
--- @return nil
function M.apply(state, row, col, rounds, payout, effect_def)
	if row == nil or col == nil then
		row, col = helpers.placement_coords(state)
	end
	if row == nil or col == nil then
		return
	end
	local resolved_rounds = (effect_def and effect_def.rounds) or rounds
	local resolved_payout = (effect_def and effect_def.payout) or payout
	M.apply_placement(state, row, col, resolved_rounds, resolved_payout)
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param default_payout number
--- @return nil
function M.on_tick(state, row, col, cell, default_payout)
	local payout_amount, owner = M.tick_cell(cell, default_payout)
	if payout_amount and owner then
		M.apply_payout(state, owner, payout_amount)
	end
end

return M
