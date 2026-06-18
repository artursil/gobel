--- Gate-only condition: pass when the selected board target is an enemy stone.
---
--- Evaluated before destroy card apply. Uses ``selected_stone.target_with_coords`` and compares
--- cell color to the effect owner from resolution metadata. Does not pass row/col in kwargs.
---
--- Condition row params: none required.
---
--- @module objects.effects_conditions.conditions.selected_target_is_enemy_stone

local board = require("board")
local config = require("config")
local selected_stone = require("objects.effects_conditions.helpers.shared.selected_stone")
local queries = require("single_game.resolver.helpers.state_queries")

local M = {}

--- Return pass when selected coordinates hold an enemy stone for the effect owner.
--- @param state table
--- @param _owner string
--- @param _condition_def table|nil
--- @return boolean pass
--- @return table|nil fragment
function M.eval(state, _owner, _condition_def)
	local target = selected_stone.target_with_coords(state)
	if not target then
		return false, nil
	end
	local owner = queries.effect_owner(state)
	if not state or not owner then
		return false, nil
	end
	local row = target.row
	local col = target.col
	local cell = state.board and state.board[row] and state.board[row][col]
	if board.is_empty(cell) then
		return false, nil
	end
	local owner_color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
	if cell.color ~= owner_color then
		return true, nil
	end
	return false, nil
end

return M
