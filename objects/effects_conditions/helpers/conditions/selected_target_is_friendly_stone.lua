--- Pass when the selected target is a friendly stone for the effect owner.
--- @module objects.effects_conditions.helpers.conditions.selected_target_is_friendly_stone

local board = require("board")
local config = require("config")
local selected_stone = require("objects.effects_conditions.helpers.shared.selected_stone")
local queries = require("single_game.resolver.helpers.state_queries")

local M = {}

--- Friendly stone at selected coordinates relative to effect owner.
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
	if cell.color == owner_color then
		return true, nil
	end
	return false, nil
end

return M
