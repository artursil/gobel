--- Placement candidate scoring orchestrator (config-driven terms + shared context).
--- @module ai.heuristics.placement

local ai_config = require("ai.config")
local ai_scoring = require("ai.scoring")
local placement_cheap = require("ai.heuristics.placement_cheap")
local placement_context = require("ai.heuristics.placement_context")
local placement_terms = require("ai.heuristics.placement_terms")

local M = {}

M.WEIGHTS = ai_config.placement.weights

--- @param view table
--- @param ctx table
--- @param placement_cfg table
--- @return number
local function score_context(view, ctx, placement_cfg)
	local my_score = placement_terms.sum_side(ctx, placement_cfg)
	local game = view:raw_game()
	local mode_key = ai_scoring.decision_mode(game)
	local total = my_score
	if mode_key == "margin" then
		local opp_ctx = placement_context.build_opponent(ctx)
		local opp_score = placement_terms.sum_side(opp_ctx, placement_cfg)
		total = ai_scoring.combine(my_score, opp_score, mode_key)
	end
	local candidate = placement_context.to_candidate(ctx, total)
	total = total + placement_terms.goals_bonus(ctx, placement_cfg, candidate)
	return total
end

--- @param view table
--- @param row integer
--- @param col integer
--- @param stone_id string
--- @param base_features table|nil
--- @param territory_before table|nil cached ``territory_analysis.analyze`` for current board
--- @return table|nil candidate
function M.evaluate_move(view, row, col, stone_id, base_features, territory_before)
	local ctx = placement_context.build(view, row, col, stone_id, base_features, territory_before)
	if not ctx then
		return nil
	end
	local placement_cfg = ai_config.for_game(view:raw_game()).placement
	local score = score_context(view, ctx, placement_cfg)
	return placement_context.to_candidate(ctx, score)
end

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
