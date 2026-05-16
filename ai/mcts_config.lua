--- Default MCTS tunables and difficulty presets for PVC / bot games.
--- See ``ai/README.md`` for how ``game.ai_strategy``, ``game.ai_difficulty``, and ``game.ai_mcts`` interact.
--- @module ai.mcts_config

local M = {}

M.DEFAULT = {
	enabled = false,
	iterations = 0,
	max_rollout_depth = 3,
	exploration_c = 1.4,
	fast_rollout = true,
	max_decision_ms = 80,
}

M.DIFFICULTY = {
	easy = {
		enabled = false,
		iterations = 0,
		max_rollout_depth = 2,
		exploration_c = 1.4,
		fast_rollout = true,
		max_decision_ms = 0,
	},
	normal = {
		enabled = false,
		iterations = 0,
		max_rollout_depth = 3,
		exploration_c = 1.4,
		fast_rollout = true,
		max_decision_ms = 0,
	},
	hard = {
		enabled = true,
		iterations = 20,
		max_rollout_depth = 3,
		exploration_c = 1.4,
		fast_rollout = true,
		max_decision_ms = 100,
	},
}

--- @param difficulty string|nil
--- @return table
function M.for_difficulty(difficulty)
	local preset = M.DIFFICULTY[difficulty] or M.DIFFICULTY.normal
	return {
		enabled = preset.enabled,
		iterations = preset.iterations,
		max_rollout_depth = preset.max_rollout_depth,
		exploration_c = preset.exploration_c,
		fast_rollout = preset.fast_rollout,
		max_decision_ms = preset.max_decision_ms,
	}
end

--- @param game table|nil
--- @param override table|nil
--- @return table
function M.resolve(game, override)
	local base = M.DEFAULT
	if game and game.ai_difficulty then
		base = M.for_difficulty(game.ai_difficulty)
	end
	if game and game.ai_mcts then
		base = {
			enabled = game.ai_mcts.enabled ~= nil and game.ai_mcts.enabled or base.enabled,
			iterations = game.ai_mcts.iterations or base.iterations,
			max_rollout_depth = game.ai_mcts.max_rollout_depth or base.max_rollout_depth,
			exploration_c = game.ai_mcts.exploration_c or base.exploration_c,
			fast_rollout = game.ai_mcts.fast_rollout ~= nil and game.ai_mcts.fast_rollout or base.fast_rollout,
			max_decision_ms = game.ai_mcts.max_decision_ms ~= nil and game.ai_mcts.max_decision_ms or base.max_decision_ms,
		}
	end
	if override then
		for k, v in pairs(override) do
			base[k] = v
		end
	end
	return base
end

--- @param game table|nil
--- @param strategy string|nil
--- @return boolean
function M.should_run(game, strategy)
	local opts = M.resolve(game, nil)
	if strategy == "heuristic" then
		if game and game.ai_mcts and game.ai_mcts.enabled == false then
			return false
		end
		if not game or not game.ai_mcts then
			return false
		end
		return opts.enabled == true and (opts.iterations or 0) > 0
	end
	if strategy == "mcts" then
		return opts.enabled ~= false and (opts.iterations or 0) > 0
	end
	return opts.enabled == true and (opts.iterations or 0) > 0
end

return M
