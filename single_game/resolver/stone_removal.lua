--- Board stone removal hooks: generic ``on_removed`` lifecycle runner on board diff.
--- @module single_game.resolver.stone_removal

local board = require("board")
local config = require("config")
local content = require("content")
local objects_effects = require("objects.effects")
local effects_helpers = require("objects.effects_helpers")

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

--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param opts table|nil
--- @return nil
function M.on_removed(state, row, col, cell, opts)
	objects_effects.apply_on_removed_effects(state, row, col, cell, opts)
end

--- @param state table
--- @param old_board table
--- @param new_board table
--- @param opts table|nil
--- @return nil
function M.apply_board_replacement_diff(state, old_board, new_board, opts)
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local old_cell = old_board[r][c]
			local new_cell = new_board[r][c]
			if not board.is_empty(old_cell) and (board.is_empty(new_cell) or old_cell.color ~= new_cell.color or old_cell.kind ~= new_cell.kind) then
				M.on_removed(state, r, c, old_cell, opts)
			end
		end
	end
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
			end
		end
	end
end

--- @param state table
--- @param row integer
--- @return nil
local function install_row_hooks(state, row)
	local backing = state.board[row]
	if backing._stone_removal_proxy then
		return
	end
	local proxy = setmetatable({}, {
		__index = backing,
		__newindex = function(_, col, value)
			local old = backing[col]
			if not board.is_empty(old) and board.is_empty(value) then
				M.on_removed(state, row, col, old, nil)
			end
			backing[col] = value
		end,
		__pairs = function()
			return pairs(backing)
		end,
	})
	backing._stone_removal_proxy = proxy
	state.board[row] = proxy
end

--- @param state table
--- @return nil
function M.install_board_hooks(state)
	if not state.board then
		return
	end
	local n = config.BOARD_SIZE
	for r = 1, n do
		install_row_hooks(state, r)
	end
end

--- @param state table
--- @return nil
function M.install_state_hooks(state)
	if state._stone_removal_hooks_installed then
		M.install_board_hooks(state)
		return
	end
	state._stone_removal_hooks_installed = true
	local mt = getmetatable(state)
	if mt and mt.__newindex then
		local prior_newindex = mt.__newindex
		mt.__newindex = function(t, k, v)
			prior_newindex(t, k, v)
			if k == "board" and type(v) == "table" then
				M.install_board_hooks(t)
			end
		end
	else
		setmetatable(state, {
			__newindex = function(t, k, v)
				rawset(t, k, v)
				if k == "board" and type(v) == "table" then
					M.install_board_hooks(t)
				end
			end,
		})
	end
	M.install_board_hooks(state)
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

return M
