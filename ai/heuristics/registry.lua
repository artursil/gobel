--- Facade for turn-plan heuristic scorers (cards, targets, stances).
--- @module ai.heuristics.registry

local cards = require("ai.heuristics.cards")
local synergy = require("ai.heuristics.synergy")
local targets = require("ai.heuristics.targets")

local M = {}

--- @param view table
--- @param hand_index integer
--- @return number
function M.score_card(view, hand_index)
	return cards.score(view, hand_index)
end

--- @param view table
--- @param hand_index integer
--- @param row integer
--- @param col integer
--- @return number
function M.score_target(view, hand_index, row, col)
	return targets.score(view, hand_index, row, col)
end

--- @param view table
--- @return number
function M.score_stance_passive(view)
	local bonus = 0
	local ids = synergy.active_stance_def_ids(view)
	for i = 1, #ids do
		bonus = bonus + 0.25
	end
	return bonus
end

return M
