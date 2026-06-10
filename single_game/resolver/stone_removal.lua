--- Board stone removal hooks (capture penalties and stored-value cleanup).
--- @module single_game.resolver.stone_removal

local board = require("board")
local config = require("config")
local economy = require("economy")
local stone_params = require("objects.parameters.stones")
local stone_stored_values = require("single_game.resolver.stone_stored_values")

local M = {}

--- @param cell table
--- @return boolean
local function is_escalating_money_stone(cell)
	return cell.kind == "escalating_money_stone"
end

--- @param state table
--- @param cell table
--- @param row integer
--- @param col integer
--- @return boolean
local function is_self_removal(state, cell, row, col)
	if not cell.placed_via_play then
		return false
	end
	local received = stone_stored_values.get(state, row, col)
	return received <= stone_params.ems_round_money
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @return nil
local function apply_escalating_money_capture_penalty(state, row, col, cell)
	if not is_escalating_money_stone(cell) then
		return
	end
	if is_self_removal(state, cell, row, col) then
		stone_stored_values.clear(state, row, col)
		return
	end
	local received = stone_stored_values.get(state, row, col)
	if received <= 0 then
		stone_stored_values.clear(state, row, col)
		return
	end
	local side = cell.color == config.STONE_WHITE and "white" or "black"
	local player = require("match_state").player_for_color(state, side)
	local penalty = stone_params.ems_capture_multiplier * received
	economy.deduct_clamped(player.resources, penalty)
	stone_stored_values.clear(state, row, col)
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param cell table
--- @param _opts table|nil
--- @return nil
function M.on_removed(state, row, col, cell, _opts)
	if board.is_empty(cell) then
		return
	end
	apply_escalating_money_capture_penalty(state, row, col, cell)
end

--- @param state table
--- @param old_board table
--- @param new_board table
--- @param _opts table|nil
--- @return nil
function M.apply_board_replacement_diff(state, old_board, new_board, _opts)
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local old_cell = old_board[r][c]
			local new_cell = new_board[r][c]
			if not board.is_empty(old_cell) and (board.is_empty(new_cell) or old_cell.color ~= new_cell.color or old_cell.kind ~= new_cell.kind) then
				M.on_removed(state, r, c, old_cell, _opts)
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
	if is_escalating_money_stone(cell) then
		stone_stored_values.set(state, row, col, 0)
	end
end

return M
