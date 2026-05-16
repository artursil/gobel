--- Territory counts via ``territory.compute_from_board`` (no duplicated assignment logic).
--- @module ai.board_analysis.territory

local board = require("board")
local config = require("config")
local territory = require("single_game.resolver.territory")

local M = {}

--- Contested: empty intersection where both sides have at least one nearest contributor.
--- @param decision table|nil
--- @return boolean
local function is_contested_decision(decision)
	if not decision or not decision.contributors then
		return false
	end
	local b_list = decision.contributors.B or {}
	local w_list = decision.contributors.W or {}
	return #b_list > 0 and #w_list > 0
end

--- @param b table
--- @param territory_mode string|nil
--- @param owner_key "B"|"W"
--- @return table
function M.analyze(b, territory_mode, owner_key)
	local grid, sources, _territory_value = territory.compute_from_board(b, territory_mode)
	local me_stone = owner_key == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
	local opp_stone = owner_key == config.OWNER_BLACK and config.STONE_WHITE or config.STONE_BLACK
	local owned_me = 0
	local owned_opp = 0
	local contested = 0
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			if board.is_empty(b[r][c]) then
				local owner_cell = grid[r][c]
				if owner_cell == me_stone then
					owned_me = owned_me + 1
				elseif owner_cell == opp_stone then
					owned_opp = owned_opp + 1
				end
				if is_contested_decision(sources[r] and sources[r][c]) then
					contested = contested + 1
				end
			end
		end
	end
	return {
		grid = grid,
		sources = sources,
		owned_me = owned_me,
		owned_opp = owned_opp,
		contested = contested,
	}
end

return M
