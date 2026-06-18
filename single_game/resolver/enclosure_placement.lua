--- Placement-time enclosure checks for stones gated by owner-enclosed territory.
--- @module single_game.resolver.enclosure_placement

local board = require("board")
local config = require("config")
local stone_params = require("objects.parameters.stones")
local territory = require("single_game.resolver.territory")
local enclosure = require("single_game.resolver.enclosure")

local M = {}

--- @param trial table
--- @param row integer
--- @param col integer
--- @return string|nil
local function empty_region_owner(trial, row, col)
	local tiles = {}
	local n = config.BOARD_SIZE
	for r = 1, n do
		tiles[r] = {}
		for c = 1, n do
			tiles[r][c] = {}
		end
	end
	local regions = enclosure.detect_regions_and_ownership(trial, tiles)
	for _, region in pairs(regions) do
		for i = 1, #region.tiles do
			local tile = region.tiles[i]
			if tile[1] == row and tile[2] == col then
				return region.owner
			end
		end
	end
	return nil
end

--- Returns whether ``(row, col)`` would be owner-enclosed empty territory on ``board_after``,
--- including boundary stones from the placed stone at that cell.
--- @param board_after table
--- @param row integer
--- @param col integer
--- @param owner string ``"B"`` | ``"W"``
--- @return boolean
function M.placement_owner_enclosed(board_after, row, col, owner)
	local trial = board.clone(board_after)
	trial[row][col] = config.STONE_NONE
	local _, decision_sources = territory.compute_from_board(trial)
	local decision = decision_sources[row] and decision_sources[row][col]
	if decision and decision.mode == "enclosure" and decision.owner == owner then
		return true
	end
	return empty_region_owner(trial, row, col) == owner
end

--- One-time placement payout when the cell is owner-enclosed; otherwise zero.
--- @param board_after table
--- @param row integer
--- @param col integer
--- @param owner string ``"B"`` | ``"W"``
--- @return integer
function M.placement_money_payout(board_after, row, col, owner)
	if not M.placement_owner_enclosed(board_after, row, col, owner) then
		return 0
	end
	return stone_params.money_field_payout
end

return M
