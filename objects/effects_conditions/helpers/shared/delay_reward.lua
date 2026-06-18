--- Delay-reward stone setup and end-of-turn payout when the timer expires.
--- @module objects.effects_conditions.helpers.shared.delay_reward

local board = require("board")
local config = require("config")
local content = require("content")
local duration_left = require("objects.effects_conditions.helpers.shared.duration_left")
local placement = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

--- @param cell table
--- @return number|nil
function M.payout_for_cell(cell)
	local stone_def = content.resolve_stone({ def_id = cell.kind, level = cell.level or 1 })
	if not stone_def or not stone_def.effects then
		return nil
	end
	for i = 1, #stone_def.effects do
		local row = stone_def.effects[i]
		if row.effect_name == "delay_reward_setup" and type(row.payout) == "number" then
			return row.payout
		end
	end
	return nil
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param rounds integer
--- @return nil
function M.setup(state, row, col, rounds)
	local cell = state.board[row] and state.board[row][col]
	if not cell or board.is_empty(cell) then
		return
	end
	cell.duration_left = rounds
	duration_left.set_tick_skip_for_placement(state, row, col)
end

--- Pay deferred payout when ``duration_left`` reached zero after the generic tick decrement.
--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @return nil
function M.payout_at_zero(state, row, col, cell)
	if duration_left.remaining(cell) ~= 0 then
		return
	end
	local payout_amount = M.payout_for_cell(cell)
	if payout_amount == nil then
		return
	end
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
--- @param row integer|nil
--- @param col integer|nil
--- @return nil
function M.setup_from_placement(state, owner, rounds, row, col)
	if not row or not col then
		row, col = placement.placement_coords(state)
	end
	if not row or not col then
		return
	end
	M.setup(state, row, col, rounds)
end

return M
