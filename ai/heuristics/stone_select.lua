--- Chooses a playable stone index for MAIN phase (Phase 1: no cards).
--- @module ai.heuristics.stone_select

local config = require("config")
local content = require("content")
local rules = require("rules")

local M = {}

--- @param stone_id string|nil
--- @return boolean
local function has_tag(stone_id, tag)
	if not stone_id then
		return false
	end
	local def = content.get_stone(stone_id)
	if not def or not def.tags then
		return false
	end
	for i = 1, #def.tags do
		if def.tags[i] == tag then
			return true
		end
	end
	return false
end

--- @param view table
--- @param stone_id string
--- @return boolean
local function has_corner_legal_move(view, stone_id)
	local b = view:board()
	local corners = {
		{ 1, 1 },
		{ 1, config.BOARD_SIZE },
		{ config.BOARD_SIZE, 1 },
		{ config.BOARD_SIZE, config.BOARD_SIZE },
	}
	for i = 1, #corners do
		local r, c = corners[i][1], corners[i][2]
		local ok = select(1, rules.try_play(b, r, c, view:stone_color(), view:ko_ban(), stone_id))
		if ok then
			return true
		end
	end
	return false
end

--- @param view table
--- @param stone_id string
--- @return number
local function score_stone(view, stone_id)
	local score = 0
	if has_tag(stone_id, "special") then
		score = score + 6
	end
	if stone_id == "stone_tower" and has_corner_legal_move(view, stone_id) then
		score = score + 4
	end
	if stone_id == "stone_influence" then
		score = score + 2
	end
	if stone_id == "stone_focus" then
		score = score + 1
	end
	if stone_id == "x_stone" or stone_id == "plus_stone" then
		score = score + 1
	end
	if stone_id == "wall" then
		score = score + 1
	end
	return score
end

--- @param view table
--- @return integer index 1-based into playable_stones
function M.choose_index(view)
	local playable = view:playable_stones()
	if #playable == 0 then
		return 1
	end
	local best_index = 1
	local best_score = -1e9
	for i = 1, #playable do
		local stone_id = playable[i]
		local s = score_stone(view, stone_id)
		if s > best_score then
			best_score = s
			best_index = i
		end
	end
	if best_score == -1e9 then
		best_index = view:rng_next_int(#playable)
	end
	return best_index
end

return M
