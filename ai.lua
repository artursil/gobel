--- Random opponent: chooses uniformly among all legal moves for the next queued stone kind.

local config = require("config")
local rules = require("rules")
local match_state = require("match_state")

local M = {}

--- Picks a random legal move for the AI color using its incoming stone kind, or nil if none.
--- @param g table game state with board, ko_ban, incoming
--- @return integer|nil row
--- @return integer|nil col
function M.random_move(g)
	local ai_state = match_state.player_for_color(g, config.AI_COLOR)
	local kind = ai_state.stones.selected_stone
	if not kind then
		return nil, nil
	end
	local moves = rules.all_legal_moves(g.board, config.AI_COLOR, g.ko_ban, kind)
	if #moves == 0 then
		return nil, nil
	end
	local idx = match_state.rng_next_int(g, #moves)
	local choice = moves[idx]
	return choice[1], choice[2]
end

return M
