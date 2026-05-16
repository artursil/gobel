--- Dispatches AI strategy and returns resolver actions (one per call).
--- @module ai.controller

local match_view = require("ai.adapters.match_view")

local STRATEGIES = {
	heuristic = require("ai.strategies.heuristic"),
	mcts = require("ai.strategies.heuristic"),
	random = require("ai.strategies.random"),
}

local M = {}

--- @return "black"|"white"
function M.bot_actor()
	return match_view.bot_actor()
end

--- @param game table
--- @return boolean
function M.is_bot_turn(game)
	return game.versus_bot == true and game.to_play == M.bot_actor()
end

--- One action per call. Phase 2: optional ``ai.search.mcts.choose_placement(view, candidates)``
--- before heuristic pick in ``ai.strategies.heuristic`` / ``ai.heuristics.placement.best_candidate``.
--- @param game table
--- @return table|nil action
--- @return string|nil signal ``"finish_main"`` to end MAIN phase without a new action type
function M.decide(game)
	if game.over or game.ended or not M.is_bot_turn(game) then
		return nil
	end
	local name = game.ai_strategy or "heuristic"
	-- ``ai_strategy == "mcts"`` uses ``strategies.heuristic``; MCTS is gated by ``mcts_config.should_run`` and ``game.ai_mcts``.
	local strategy = STRATEGIES[name] or STRATEGIES.heuristic
	local view = match_view.for_actor(game, M.bot_actor())
	return strategy.choose_action(view)
end

return M
