--- Backward-compatible MCTS accessors; delegates to ``ai.config``.
--- @module ai.mcts_config

local ai_config = require("ai.config")

local M = {}

M.DEFAULT = ai_config.mcts

M.DIFFICULTY = {}
for name, profile in pairs(ai_config.profiles) do
	M.DIFFICULTY[name] = profile.mcts
end

--- @param difficulty string|nil
--- @return table
function M.for_difficulty(difficulty)
	return ai_config.for_game({ ai_difficulty = difficulty or "normal" }).mcts
end

--- @param game table|nil
--- @param override table|nil
--- @return table
function M.resolve(game, override)
	local base = ai_config.for_game(game).mcts
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
	return ai_config.mcts_should_run(game, strategy)
end

return M
