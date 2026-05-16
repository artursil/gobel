--- Monte Carlo tree search over placement candidates (Phase 2 scaffold).
---
--- Planned: MCTS over top-K placement candidates only; rollouts use the feature evaluator
--- from ``ai.heuristics.placement``; ``ai.heuristics.goals`` adds bonus terms to leaf/candidate
--- scores. Opponent modeling deferred. No implementation in Phase 1.
--- @module ai.search.mcts

local M = {}

--- Phase 2 entry: call from heuristic place phase before ``placement.best_candidate``.
--- @param _view table
--- @param _candidates table[]
--- @return table|nil chosen candidate with ``row`` and ``col``, or nil to fall back to heuristic
function M.choose_placement(_view, _candidates)
	return nil
end

return M
