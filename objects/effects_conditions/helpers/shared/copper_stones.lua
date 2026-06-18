--- Owner copper stone counting shared by conditions and effects.
--- @module objects.effects_conditions.helpers.shared.copper_stones

local board = require("board")
local config = require("config")

local M = {}

local COPPER_STONE_KIND = "copper_stone"

local function owner_color(owner)
	return owner == config.OWNER_WHITE and config.STONE_WHITE or config.STONE_BLACK
end

--- Count owner copper stones, optionally excluding one cell.
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

return M
