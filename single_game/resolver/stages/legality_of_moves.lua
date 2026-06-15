--- Refresh cached placement legality from board, immunity, blockade, and ko.
--- @module single_game.resolver.stages.legality_of_moves

local config = require("config")
local rules = require("rules")

local M = {}

--- @param state table
--- @return nil
function M.run(state)
	state.legal_moves_cache = state.legal_moves_cache or {}
	local sides = { "black", "white" }
	for i = 1, #sides do
		local side = sides[i]
		local player = side == "white" and config.STONE_WHITE or config.STONE_BLACK
		local actor_state = require("match_state").player_for_color(state, side)
		local stone_id = actor_state
			and actor_state.stones
			and actor_state.stones.selected_stone
		if not stone_id and actor_state and actor_state.stones and actor_state.stones.playable_stones then
			stone_id = actor_state.stones.playable_stones[1]
		end
		stone_id = stone_id or "stone_basic"
		state.legal_moves_cache[side] = rules.all_legal_moves(
			state.board,
			player,
			state.ko_ban,
			stone_id
		)
	end
end

return M
