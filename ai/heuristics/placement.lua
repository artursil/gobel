--- Scores a single placement candidate from board + trial features.
--- @module ai.heuristics.placement

local ai_config = require("ai.config")
local ai_scoring = require("ai.scoring")
local config = require("config")
local features = require("ai.board_analysis.features")
local goals = require("ai.heuristics.goals")
local placement_cheap = require("ai.heuristics.placement_cheap")
local snapshot = require("ai.board_analysis.snapshot")
local territory_analysis = require("ai.board_analysis.territory")
local rules = require("rules")

local M = {}

M.WEIGHTS = ai_config.placement.weights

--- @param w table
--- @param before table
--- @param after table
--- @param b table
--- @param row integer
--- @param col integer
--- @param stone_color integer
--- @param owner_key "B"|"W"
--- @param walls table|nil
--- @param captures integer
--- @return number
local function placement_delta_score(w, before, after, b, row, col, stone_color, owner_key, walls, captures)
	local delta_me = after.territory_owned_me - before.territory_owned_me
	local delta_inside = after.largest_enclosure_inside_me - before.largest_enclosure_inside_me
	local closes_region = delta_inside > 0 or (delta_me > 0 and after.territory_contested < before.territory_contested)
	local score = 0
	score = score + w.delta_territory_me * delta_me
	score = score + w.delta_captures * captures
	score = score + w.delta_enclosure_inside * math.max(0, delta_inside)
	if closes_region then
		score = score + w.closes_region
	end
	if features.is_placement_frontier(b, row, col, stone_color, walls, owner_key) then
		score = score + w.frontier
	end
	if before.territory_contested > 0 and delta_me > 0 then
		score = score + w.contested_pressure
	end
	if after.weak_boundary_cells > before.weak_boundary_cells then
		score = score + w.weak_boundary_penalty * (after.weak_boundary_cells - before.weak_boundary_cells)
	end
	if captures == 0
		and not features.is_placement_frontier(b, row, col, stone_color, walls, owner_key)
		and delta_me <= 0 then
		score = score + w.self_fill_penalty
	end
	return score
end

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
	local game = view:raw_game()
	local mode_key = ai_scoring.decision_mode(game)
	local my_score = placement_delta_score(w, before, after, b, row, col, player, owner_key, before._walls, captures)
	local score = my_score
	if mode_key == "margin" then
		local opp_owner = owner_key == config.OWNER_BLACK and config.OWNER_WHITE or config.OWNER_BLACK
		local opp_color = player == config.STONE_BLACK and config.STONE_WHITE or config.STONE_BLACK
		local terr_opp_before = territory_analysis.analyze(b, mode, opp_owner)
		local before_opp = features.build(b, view:ko_ban(), opp_owner, mode, opp_color, terr_opp_before, before._walls)
		local after_opp_counts = territory_analysis.analyze(trial_board, mode, opp_owner)
		local after_opp = features.build(trial_board, after_ko, opp_owner, mode, opp_color, after_opp_counts, before._walls)
		local opp_score = placement_delta_score(w, before_opp, after_opp, b, row, col, opp_color, opp_owner, before._walls, 0)
		score = ai_scoring.combine(my_score, opp_score, mode_key)
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
	local game = view:raw_game()
	local settings = ai_config.for_game(game)
	local placement_cfg = settings.placement
	local mcts = require("ai.search.mcts")
	local mcts_opts = {
		territory_before = territory_before,
		walls = base_features and base_features._walls or nil,
	}
	for k, v in pairs(settings.mcts) do
		mcts_opts[k] = v
	end
	local mcts_pick = mcts.choose_placement(view, candidates, mcts_opts)
	if mcts_pick and mcts_pick.row and mcts_pick.col then
		local scored = M.evaluate_move(view, mcts_pick.row, mcts_pick.col, stone_id, base_features, territory_before)
		return scored or { row = mcts_pick.row, col = mcts_pick.col, score = 0 }
	end
	local walls = base_features and base_features._walls or nil
	local pool = candidates
	local cap = placement_cfg.full_eval_top_n
	if placement_cfg.prescore_enabled and #candidates > cap then
		pool = placement_cheap.top_by_cheap_score(view, candidates, stone_id, walls, cap)
	elseif not placement_cfg.prescore_enabled and #candidates > cap then
		pool = {}
		for i = 1, cap do
			pool[i] = candidates[i]
		end
	end
	local best = nil
	for i = 1, #pool do
		local move = pool[i]
		local scored = M.evaluate_move(view, move.row, move.col, stone_id, base_features, territory_before)
		if scored and (not best or scored.score > best.score) then
			best = scored
		end
	end
	return best
end

return M
