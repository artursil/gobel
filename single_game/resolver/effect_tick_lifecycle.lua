--- Generic tick lifecycle runner: scans the board for cell-owned timer fields and zone maps.
---
--- Cell-owned fields (``survival_rounds_remaining``, ``immunity_remaining``) tick via effect
--- ``on_tick`` hooks. ``blockade_adjacent`` is the documented exception: duration lives on the
--- board-zone ``placement_blocks`` map for orthogonally adjacent empty cells.
--- @module single_game.resolver.effect_tick_lifecycle

local board = require("board")
local config = require("config")
local objects_effects = require("objects.effects")
local anti_capture_immunity = require("single_game.resolver.anti_capture_immunity")

local M = {}

--- Maps a cell-owned runtime field to its effect_name tick handler.
local CELL_FIELD_TO_EFFECT = {
	survival_rounds_remaining = "delay_reward_survival",
	immunity_remaining = "anti_capture_immunity",
}

--- @param effect_name string
--- @return table|nil resolved effect builder output
local function resolved_tick_handler(effect_name)
	return objects_effects.resolve({ effect_name = effect_name, macro = "playing_stones", sub = "points" })
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param field string
--- @param opts table|nil ``{ skip_cell = { row, col } }``
--- @return nil
local function tick_cell_field(state, row, col, cell, field, opts)
	local skip = opts and opts.skip_cell
	if skip and skip.row == row and skip.col == col then
		return
	end
	local remaining = cell[field]
	if type(remaining) ~= "number" or remaining <= 0 then
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

--- Decrements cell-owned timer fields and runs expiry hooks.
--- @param state table
--- @param opts table|nil ``{ skip_cell = { row, col } }``
--- @return nil
function M.tick_cell_owned_fields(state, opts)
	opts = opts or {}
	anti_capture_immunity.ensure_materialized_from_board(state)
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local cell = state.board[r][c]
			if not board.is_empty(cell) then
				for field in pairs(CELL_FIELD_TO_EFFECT) do
					if cell[field] ~= nil then
						tick_cell_field(state, r, c, cell, field, opts)
					end
				end
			end
		end
	end
	if opts and opts.skip_cell then
		opts.skip_cell = nil
	end
end

--- Ticks blockade zone durations (board-zone map exception).
--- @param state table
--- @return nil
function M.tick_blockade_zones(state)
	local handler = resolved_tick_handler("blockade_adjacent")
	if handler and handler.on_tick then
		handler.on_tick(state)
	end
end

--- Full tick pass: cell-owned fields, then blockade zones when appropriate.
--- @param state table
--- @param opts table|nil ``{ skip_cell = { row, col }, tick_blockade = boolean }``
--- @return nil
function M.tick(state, opts)
	opts = opts or {}
	M.tick_cell_owned_fields(state, opts)
	if opts.tick_blockade ~= false then
		M.tick_blockade_zones(state)
	end
end

return M
