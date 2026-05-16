--- Uniform random stone selection and placement (legacy bot behavior).
--- @module ai.strategies.random

local config = require("config")
local match_state = require("match_state")
local rules = require("rules")

local M = {}

--- @param g table
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

--- @param view table
--- @return table|nil action
--- @return string|nil signal
function M.choose_action(view)
	local g = view:raw_game()
	if view:phase() == "MAIN_PHASE" then
		local playable = view:playable_stones()
		if #playable == 0 then
			return nil, "finish_main"
		end
		local idx = view:rng_next_int(#playable)
		if view:selected_stone_index() ~= idx or view:selected_stone_id() ~= playable[idx] then
			return {
				actor = view:actor(),
				type = "SELECT_STONE",
				payload = { stone_id = playable[idx], stone_index = idx },
			}
		end
		return nil, "finish_main"
	end
	if view:phase() == "PLACE_PHASE" then
		local r, c = M.random_move(g)
		if not r then
			return {
				actor = view:actor(),
				type = "PASS_TURN",
				payload = {},
			}
		end
		return {
			actor = view:actor(),
			type = "PLACE_STONE",
			payload = { row = r, col = c },
		}
	end
	return nil
end

return M
