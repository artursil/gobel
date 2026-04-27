local config = require("config")
local scoring = require("scoring")

local M = {}

function M.calculate_base(state)
	state.territory = scoring.territory_map(state.board, state.territory_mode)
	local black_controlled = scoring.territory_points(state.territory, config.STONE_BLACK)
	local white_controlled = scoring.territory_points(state.territory, config.STONE_WHITE)
	state.scores.territory.A = state.turn_number * black_controlled
	state.scores.territory.B = state.turn_number * white_controlled
end

return M
