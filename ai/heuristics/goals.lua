--- Strategic goals blackboard (Phase 2 scaffold).
---
--- Phase 2 will attach weighted goals (e.g. expand enclosure, contest center) that add
--- bonuses to placement candidate scores before MCTS selection. No behavior in Phase 1.
--- @module ai.heuristics.goals

local M = {}

--- Phase 1 tests may set this to verify wiring (not used in production).
M._test_bonus = nil

--- Bonus added in ``placement.evaluate_move`` after base feature score.
--- @param _view table match view for the deciding side
--- @param candidate table ``{ row, col, score?, delta_territory_me?, delta_captures?, delta_enclosure_inside?, closes_region? }``
--- @return number
function M.candidate_bonus(_view, candidate)
	if M._test_bonus ~= nil then
		return M._test_bonus
	end
	return 0
end

return M
