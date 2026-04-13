--- Random opponent: chooses uniformly among all legal moves for the next queued stone kind.

local config = require("config")
local rules = require("rules")
local stone_queue = require("stone_queue")

local M = {}

--- Picks a random legal move for the AI color using its incoming stone kind, or nil if none.
--- @param g table game state with board, ko_ban, incoming
--- @return integer|nil row
--- @return integer|nil col
function M.random_move(g)
	local kind = stone_queue.peek_next_kind(g, config.AI_COLOR)
	local moves = rules.all_legal_moves(g.board, config.AI_COLOR, g.ko_ban, kind)
	if #moves == 0 then
		return nil, nil
	end
	local idx = love.math.random(#moves)
	local choice = moves[idx]
	return choice[1], choice[2]
end

return M
