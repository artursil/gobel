--- Explicit ``on_removed`` dispatch after board diffs; sacrifice cells may be excluded.
--- @module single_game.resolver.stages.dispatch_removed

local board = require("board")
local config = require("config")
local content = require("content")
local effects_helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

--- @param stone_def table|nil
--- @return boolean
local function stone_tracks_stored_value(stone_def)
	if not stone_def or not stone_def.effects then
		return false
	end
	for i = 1, #stone_def.effects do
		local effect_name = stone_def.effects[i].effect_name
		if effect_name == "escalating_money_tracker" or effect_name == "escalating_points_bank" then
			return true
		end
	end
	return false
end

--- @param opts table|nil
--- @param row integer
--- @param col integer
--- @return boolean
local function should_skip_cell(opts, row, col)
	if not opts then
		return false
	end
	local skip = opts.skip_sacrifice_cells
	if not skip then
		local single = opts.skip_sacrifice_cell
		if single and single.row == row and single.col == col then
			return true
		end
		return false
	end
	for i = 1, #skip do
		local entry = skip[i]
		if entry.row == row and entry.col == col then
			return true
		end
	end
	return false
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param opts table|nil
--- @return nil
function M.on_removed(state, row, col, cell, opts)
	local objects_effects = require("objects.effects_conditions.effects")
	objects_effects.apply_on_removed_effects(state, row, col, cell, opts)
end

--- @param old_board table
--- @param new_board table
--- @return nil
function M.preserve_cell_metadata(old_board, new_board)
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local old_cell = old_board[r][c]
			local new_cell = new_board[r][c]
			if board.is_empty(old_cell) or board.is_empty(new_cell) then
			elseif old_cell.color == new_cell.color and old_cell.kind == new_cell.kind then
				new_cell.placed_via_play = old_cell.placed_via_play
				new_cell.placed_turn_number = old_cell.placed_turn_number
				if old_cell.stored_value ~= nil then
					new_cell.stored_value = old_cell.stored_value
				end
				if old_cell.duration_left ~= nil then
					new_cell.duration_left = old_cell.duration_left
				end
				if old_cell.survival_rounds_remaining ~= nil then
					new_cell.survival_rounds_remaining = old_cell.survival_rounds_remaining
				end
				if old_cell.timer_remaining_rounds ~= nil then
					new_cell.timer_remaining_rounds = old_cell.timer_remaining_rounds
				end
				if old_cell.delay_payout ~= nil then
					new_cell.delay_payout = old_cell.delay_payout
				end
				if old_cell.immunity_remaining ~= nil then
					new_cell.immunity_remaining = old_cell.immunity_remaining
				end
			end
		end
	end
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return nil
function M.mark_placed_via_play(state, row, col)
	local cell = state.board and state.board[row] and state.board[row][col]
	if type(cell) ~= "table" or board.is_empty(cell) then
		return
	end
	cell.placed_via_play = true
	cell.placed_turn_number = state.turn_number or 1
	local stone_def = content.resolve_stone(cell.kind)
	if stone_tracks_stored_value(stone_def) then
		effects_helpers.set_stone_stored_value(state, row, col, 0)
	end
end

--- Diff boards and dispatch ``on_removed`` for cells that lost stones.
--- @param state table
--- @param old_board table
--- @param new_board table
--- @param opts table|nil ``{ capturer, skip_sacrifice_cells, skip_sacrifice_cell }``
--- @return nil
function M.run(state, old_board, new_board, opts)
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			if should_skip_cell(opts, r, c) then
			else
				local old_cell = old_board[r][c]
				local new_cell = new_board[r][c]
				if not board.is_empty(old_cell)
					and (board.is_empty(new_cell) or old_cell.color ~= new_cell.color or old_cell.kind ~= new_cell.kind) then
					M.on_removed(state, r, c, old_cell, opts)
				end
			end
		end
	end
end

return M
