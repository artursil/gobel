--- Random opponent: chooses uniformly among all legal moves.

local config = require("config")
local rules = require("rules")

local M = {}

--- Picks a random legal move for the AI color, or nil if there are none.
--- @param game_board table
--- @param ko_ban table|nil
--- @return integer|nil row
--- @return integer|nil col
function M.random_move(game_board, ko_ban)
	local moves = rules.all_legal_moves(game_board, config.AI_COLOR, ko_ban)
	if #moves == 0 then
		return nil, nil
	end
	local idx = love.math.random(#moves)
	local choice = moves[idx]
	return choice[1], choice[2]
end

return M
