--- Placement legality helpers for ``kamikaze_stone`` (suicide override eligibility).
--- @module single_game.resolver.kamikaze_stone

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

return M
