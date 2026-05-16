--- Scores a single placement candidate from board + trial features.
--- @module ai.heuristics.placement

local features = require("ai.board_analysis.features")
local goals = require("ai.heuristics.goals")
local snapshot = require("ai.board_analysis.snapshot")
local territory_analysis = require("ai.board_analysis.territory")
local rules = require("rules")

local M = {}

--- Tune placement behavior here (Phase 1 defaults).
M.WEIGHTS = {
	delta_territory_me = 4.0,
	delta_captures = 12.0,
	delta_enclosure_inside = 2.5,
	closes_region = 3.0,
	frontier = 2.0,
	contested_pressure = 1.5,
	weak_boundary_penalty = -1.0,
	self_fill_penalty = -6.0,
}

--- @param view table
--- @param row integer
--- @param col integer
--- @param stone_id string
--- @param base_features table|nil
--- @param territory_before table|nil cached ``territory_analysis.analyze`` for current board
--- @return table|nil candidate
function M.evaluate_move(view, row, col, stone_id, base_features, territory_before)
	local b = view:board()
	local player = view:stone_color()
	local owner_key = view:owner_key()
	local mode = view:territory_mode()
	local ok, trial_board, new_ko, captures = rules.try_play(b, row, col, player, view:ko_ban(), stone_id)
	if not ok then
		return nil
	end
	local counts_before = territory_before
		or (base_features and {
			owned_me = base_features.territory_owned_me,
			owned_opp = base_features.territory_owned_opp,
			contested = base_features.territory_contested,
			grid = base_features._territory_grid,
			sources = nil,
		})
	local before = base_features
		or features.build(b, view:ko_ban(), owner_key, mode, player, counts_before, nil)
	local after_ko = snapshot.clone_ko(new_ko)
	local after_counts = territory_analysis.analyze(trial_board, mode, owner_key)
	local after = features.build(trial_board, after_ko, owner_key, mode, player, after_counts, before._walls)
	local delta_me = after.territory_owned_me - before.territory_owned_me
	local delta_inside = after.largest_enclosure_inside_me - before.largest_enclosure_inside_me
	local closes_region = delta_inside > 0 or (delta_me > 0 and after.territory_contested < before.territory_contested)

	local w = M.WEIGHTS
	local score = 0
	score = score + w.delta_territory_me * delta_me
	score = score + w.delta_captures * captures
	score = score + w.delta_enclosure_inside * math.max(0, delta_inside)
	if closes_region then
		score = score + w.closes_region
	end
	if features.is_placement_frontier(b, row, col, player, before._walls, owner_key) then
		score = score + w.frontier
	end
	if before.territory_contested > 0 and delta_me > 0 then
		score = score + w.contested_pressure
	end
	if after.weak_boundary_cells > before.weak_boundary_cells then
		score = score + w.weak_boundary_penalty * (after.weak_boundary_cells - before.weak_boundary_cells)
	end
	if captures == 0 and not features.is_placement_frontier(b, row, col, player, before._walls, owner_key) and delta_me <= 0 then
		score = score + w.self_fill_penalty
	end

	local candidate = {
		row = row,
		col = col,
		delta_territory_me = delta_me,
		delta_captures = captures,
		delta_enclosure_inside = delta_inside,
		closes_region = closes_region,
		score = score,
	}
	candidate.score = candidate.score + goals.candidate_bonus(view, candidate)
	return candidate
end

--- Phase 2: optional ``mcts.choose_placement(view, candidates)`` before this heuristic pick.
--- @param view table
--- @param candidates table[]
--- @param stone_id string
--- @param base_features table|nil
--- @param territory_before table|nil
--- @return table|nil best
function M.best_candidate(view, candidates, stone_id, base_features, territory_before)
	local mcts = require("ai.search.mcts")
	local mcts_pick = mcts.choose_placement(view, candidates)
	if mcts_pick and mcts_pick.row and mcts_pick.col then
		return mcts_pick
	end
	local best = nil
	for i = 1, #candidates do
		local move = candidates[i]
		local scored = M.evaluate_move(view, move.row, move.col, stone_id, base_features, territory_before)
		if scored and (not best or scored.score > best.score) then
			best = scored
		end
	end
	return best
end

return M
