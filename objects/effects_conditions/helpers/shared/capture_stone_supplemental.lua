--- Pick supplemental capture-stone target after regular Go captures at commit.
--- @module objects.effects_conditions.helpers.shared.capture_stone_supplemental

local board = require("board")
local config = require("config")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

--- Opponent chain color for the effect owner placing capture stone.
--- @param owner string
--- @return integer
local function opponent_chain_color(owner)
	local player_chain_color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
	return board.opponent_stone(player_chain_color)
end

--- Enemy stones at zero empty neighbors still on board after commit captures.
--- @param state table
--- @param owner string
--- @return integer|nil row
--- @return integer|nil col
function M.pick_supplemental_target(state, owner)
	local opponent = opponent_chain_color(owner)
	local candidates = helpers.enemy_stones_at_zero_empty_neighbors(state.board, opponent)
	if #candidates == 0 then
		return nil, nil
	end
	local pick = helpers.pick_capture_candidate_index(state, "capture_stone", #candidates)
	local target = candidates[pick]
	return target.row, target.col
end

return M
