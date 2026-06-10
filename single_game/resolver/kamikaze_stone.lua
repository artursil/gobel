--- Sacrifice placement rules for ``kamikaze_stone`` (legality override, payout, self-removal).
--- @module single_game.resolver.kamikaze_stone

local board = require("board")
local rules = require("rules")
local stone_params = require("objects.parameters.stones")

local M = {}

local STONE_ID = "kamikaze_stone"

--- @param stone_id string|nil
--- @return boolean
function M.is_kamikaze_stone(stone_id)
	return stone_id == STONE_ID
end

--- @param stone_id string|nil
--- @return boolean
function M.allows_suicide_placement(stone_id)
	return M.is_kamikaze_stone(stone_id)
end

--- @param b table
--- @param row integer
--- @param col integer
--- @return boolean
local function empty_cell_has_no_empty_neighbors(b, row, col)
	for nr, nc in rules.each_neighbor(row, col) do
		if board.is_empty(b[nr][nc]) then
			return false
		end
	end
	return true
end

--- @param opts table|nil
--- @return boolean
local function on_capture_cooldown_sacrifice(opts)
	if not opts or not opts.on_capture_cooldown_cell then
		return false
	end
	return opts.empty_cell_had_no_empty_neighbors == true
end

--- @param opts table|nil
--- @return boolean
--- @return integer
function M.resolve_placement(opts)
	if on_capture_cooldown_sacrifice(opts) then
		return true, stone_params.kamikaze_points_bonus
	end
	if opts and opts.required_suicide_override then
		return true, stone_params.kamikaze_points_bonus
	end
	return false, 0
end

--- @param b table
--- @param row integer
--- @param col integer
--- @return boolean
function M.empty_cell_has_no_empty_neighbors(b, row, col)
	return empty_cell_has_no_empty_neighbors(b, row, col)
end

return M
