--- Decision-score helpers: absolute (maximize own) vs margin (own − opponent).
--- @module ai.scoring

local ai_config = require("ai.config")
local match_state = require("match_state")

local M = {}

--- @param game table|nil
--- @return "absolute"|"margin"
function M.decision_mode(game)
	local scoring = ai_config.for_game(game).scoring
	return scoring.decision_mode or "absolute"
end

--- @param my_value number
--- @param opp_value number
--- @param mode "absolute"|"margin"|nil
--- @return number
function M.combine(my_value, opp_value, mode)
	if mode == "margin" then
		return my_value - opp_value
	end
	return my_value
end

--- @param player table
--- @return number
function M.match_score_total(player)
	local s = player.score
	return (s.turn_bonus or 1)
		* (s.territory or 0)
		* (s.points or 1)
		* (s.plus_mult or 1)
		* (s.x_mult or 1)
end

--- @param view table
--- @return number
--- @return number
function M.match_margin_from_view(view)
	local game = view:raw_game()
	local me = view:player()
	local opp_actor = view:actor() == "white" and "black" or "white"
	local opp = match_state.player_for_color(game, opp_actor)
	return M.match_score_total(me), M.match_score_total(opp)
end

return M
