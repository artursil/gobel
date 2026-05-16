--- Strategic goals blackboard: refreshed once per placement decision.
--- @module ai.heuristics.goals

local rules = require("rules")

local M = {}

M._test_bonus = nil

local GOAL_WEIGHTS = {
	expand_enclosure = 4,
	claim_contested = 3,
	cut_connectivity = 6,
}

--- @param game table
--- @param id string
--- @param weight number
--- @return nil
local function activate_goal(game, id, weight)
	game.ai_goals = game.ai_goals or {}
	game.ai_goals[#game.ai_goals + 1] = { id = id, weight = weight }
end

--- @param game table
--- @param id string
--- @return boolean
local function goal_active(game, id)
	if not game or not game.ai_goals then
		return false
	end
	for i = 1, #game.ai_goals do
		if game.ai_goals[i].id == id then
			return true
		end
	end
	return false
end

--- @param view table
--- @return boolean
local function capture_possible(view)
	local stone_id = view:selected_stone_id()
	if not stone_id then
		local playable = view:playable_stones()
		if #playable == 0 then
			return false
		end
		stone_id = playable[1]
	end
	local b = view:board()
	local player = view:stone_color()
	local ko = view:ko_ban()
	local legal = rules.all_legal_moves(b, player, ko, stone_id)
	for i = 1, #legal do
		local row, col = legal[i][1], legal[i][2]
		local ok, _, _, captures = rules.try_play(b, row, col, player, ko, stone_id)
		if ok and captures > 0 then
			return true
		end
	end
	return false
end

--- @param view table
--- @param base_features table
--- @param _territory_before table|nil
--- @return nil
function M.refresh(view, base_features, _territory_before)
	local game = view:raw_game()
	game.ai_goals = {}
	if base_features.largest_enclosure_inside_me > 0 then
		activate_goal(game, "expand_enclosure", GOAL_WEIGHTS.expand_enclosure)
	end
	if base_features.territory_contested > 0 then
		activate_goal(game, "claim_contested", GOAL_WEIGHTS.claim_contested)
	end
	if capture_possible(view) then
		activate_goal(game, "cut_connectivity", GOAL_WEIGHTS.cut_connectivity)
	end
end

--- @param _view table
--- @param candidate table
--- @return number
function M.candidate_bonus(_view, candidate)
	if M._test_bonus ~= nil then
		return M._test_bonus
	end
	local game = _view:raw_game()
	local bonus = 0
	if goal_active(game, "expand_enclosure") and (candidate.delta_enclosure_inside or 0) > 0 then
		bonus = bonus + GOAL_WEIGHTS.expand_enclosure
	end
	if goal_active(game, "claim_contested") and (candidate.delta_territory_me or 0) > 0 then
		bonus = bonus + GOAL_WEIGHTS.claim_contested
	end
	if goal_active(game, "cut_connectivity") and (candidate.delta_captures or 0) > 0 then
		bonus = bonus + GOAL_WEIGHTS.cut_connectivity
	end
	return bonus
end

--- @param game table|nil
--- @param feat table
--- @return number
function M.position_bonus(game, feat)
	if not game or not game.ai_goals then
		return 0
	end
	local bonus = 0
	if goal_active(game, "expand_enclosure") and feat.largest_enclosure_inside_me > 0 then
		bonus = bonus + GOAL_WEIGHTS.expand_enclosure * 0.5
	end
	if goal_active(game, "claim_contested") and feat.territory_contested > 0 then
		bonus = bonus + GOAL_WEIGHTS.claim_contested * 0.5
	end
	return bonus
end

return M
