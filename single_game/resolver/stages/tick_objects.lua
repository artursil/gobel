--- Generic end-of-turn timer decrement and timed stone expiry (no effect semantics).
--- @module single_game.resolver.stages.tick_objects

local board = require("board")
local config = require("config")
local anti_capture_immunity = require("single_game.resolver.anti_capture_immunity")
local territory_control_rounds = require("single_game.resolver.helpers.territory_control_rounds")

local M = {}

M.CELL_TIMER_FIELDS = {
	"survival_rounds_remaining",
	"immunity_remaining",
	"timer_remaining_rounds",
}

local CELL_FIELD_TO_EFFECT = {
	survival_rounds_remaining = "delay_reward_survival",
	immunity_remaining = "anti_capture_immunity",
}

--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param key string
--- @return integer|nil row
--- @return integer|nil col
local function parse_cell_key(key)
	local row_s, col_s = key:match("^(%d+):(%d+)$")
	if not row_s or not col_s then
		return nil, nil
	end
	return tonumber(row_s), tonumber(col_s)
end

--- @param cell table
--- @param field string
--- @return nil
local function decrement_cell_field(cell, field)
	local remaining = cell[field]
	if type(remaining) ~= "number" or remaining <= 0 then
		return
	end
	remaining = remaining - 1
	if remaining <= 0 then
		cell[field] = nil
		return
	end
	cell[field] = remaining
end

--- @param state table
--- @param opts table|nil ``{ skip_cell = { row, col }, decrement_board_cell_timers = boolean }``
--- @return nil
function M.decrement(state, opts)
	opts = opts or {}
	local skip = opts.skip_cell
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			if skip and skip.row == r and skip.col == c then
			else
				local cell = state.board[r][c]
				if not board.is_empty(cell) then
					for i = 1, #M.CELL_TIMER_FIELDS do
						local field = M.CELL_TIMER_FIELDS[i]
						if cell[field] ~= nil then
							decrement_cell_field(cell, field)
						end
					end
				end
			end
		end
	end
	if opts.decrement_board_cell_timers and state.board_cell_timers then
		for key, remaining in pairs(state.board_cell_timers) do
			if type(remaining) == "number" and remaining > 0 then
				state.board_cell_timers[key] = remaining - 1
			end
		end
	end
end

--- Remove stones whose ``board_cell_timers`` reached zero (no scoring payout).
--- @param state table
--- @return nil
function M.remove_expired_timed_stones(state)
	if not state.board_cell_timers then
		return
	end
	local expired_keys = {}
	for key, remaining in pairs(state.board_cell_timers) do
		if type(remaining) == "number" and remaining <= 0 then
			expired_keys[#expired_keys + 1] = key
		end
	end
	for i = 1, #expired_keys do
		local key = expired_keys[i]
		state.board_cell_timers[key] = nil
		local row, col = parse_cell_key(key)
		if row and col and state.board[row] and state.board[row][col] then
			local cell = state.board[row][col]
			if not board.is_empty(cell) then
				state.board[row][col] = config.STONE_NONE
				territory_control_rounds.clear_cell(state, row, col)
			end
		end
	end
end

--- @param effect_name string
--- @return table|nil resolved effect builder output
local function resolved_tick_handler(effect_name)
	local objects_effects = require("objects.effects")
	return objects_effects.resolve({ effect_name = effect_name, macro = "playing_stones", sub = "points" })
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param field string
--- @param opts table|nil
--- @return nil
local function run_cell_field_side_effect(state, row, col, cell, field, opts)
	local skip = opts and opts.skip_cell
	if skip and skip.row == row and skip.col == col then
		return
	end
	local effect_name = CELL_FIELD_TO_EFFECT[field]
	if not effect_name then
		return
	end
	local handler = resolved_tick_handler(effect_name)
	if handler and handler.on_tick then
		handler.on_tick(state, row, col, cell, field)
	end
end

--- Timer side effects after dumb decrement (payout, immunity cleanup, blockade shrink).
--- @param state table
--- @param opts table|nil ``{ skip_cell = { row, col }, tick_blockade = boolean }``
--- @return nil
function M.run_side_effects(state, opts)
	opts = opts or {}
	anti_capture_immunity.ensure_materialized_from_board(state)
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local cell = state.board[r][c]
			if not board.is_empty(cell) then
				for field in pairs(CELL_FIELD_TO_EFFECT) do
					if cell[field] ~= nil then
						run_cell_field_side_effect(state, r, c, cell, field, opts)
					end
				end
				if cell.delay_payout ~= nil then
					run_cell_field_side_effect(state, r, c, cell, "survival_rounds_remaining", opts)
				end
			end
		end
	end
	if opts.tick_blockade ~= false then
		local handler = resolved_tick_handler("blockade_adjacent")
		if handler and handler.on_tick then
			handler.on_tick(state)
		end
	end
end

--- Decrement timers, optionally expire timed stones; does not run side effects.
--- @param state table
--- @param opts table|nil
--- @return nil
function M.run(state, opts)
	M.decrement(state, opts)
	if opts and opts.remove_expired_timed_stones then
		M.remove_expired_timed_stones(state)
	end
end

return M
