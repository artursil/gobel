--- Copper threshold counting for copper_stone placement bonus.
--- @module objects.helper_effects.copper_threshold_plus_mult

local board = require("board")
local config = require("config")
local stone_params = require("objects.parameters.stones")

local M = {}

local COPPER_STONE_KIND = "copper_stone"

--- @param owner string ``"B"`` | ``"W"``
--- @return integer
local function owner_color(owner)
	return owner == config.OWNER_WHITE and config.STONE_WHITE or config.STONE_BLACK
end

--- Counts owner copper stones on the board, optionally skipping one cell.
--- @param board_grid table
--- @param owner string ``"B"`` | ``"W"``
--- @param exclude_row integer|nil
--- @param exclude_col integer|nil
--- @return integer
function M.count_owner_copper_on_board(board_grid, owner, exclude_row, exclude_col)
	local color = owner_color(owner)
	local count = 0
	local n = config.BOARD_SIZE
	for row = 1, n do
		for col = 1, n do
			if row ~= exclude_row or col ~= exclude_col then
				local cell = board_grid[row][col]
				if not board.is_empty(cell) and cell.kind == COPPER_STONE_KIND and cell.color == color then
					count = count + 1
				end
			end
		end
	end
	return count
end

--- Returns threshold plus_mult when the owner already had at least ``copper_threshold`` coppers before this placement.
--- @param board_after table post-placement board
--- @param row integer placement row
--- @param col integer placement col
--- @param owner string ``"B"`` | ``"W"``
--- @return integer
function M.placement_threshold_plus_mult(board_after, row, col, owner)
	local before_count = M.count_owner_copper_on_board(board_after, owner, row, col)
	if before_count >= stone_params.copper_threshold then
		return stone_params.copper_threshold_plus_mult_bonus
	end
	return 0
end

--- @param state table
--- @param owner string
--- @param row integer|nil
--- @param col integer|nil
--- @param effect_def table|nil
--- @return nil
function M.apply(state, owner, row, col, effect_def)
	if not row or not col then
		return
	end
	local bonus = (effect_def and effect_def.value) or stone_params.copper_threshold_plus_mult_bonus
	state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + bonus
end

return M
