--- Plus_mult from territory control streak at the placed cell.
--- @module objects.helper_effects.mult_control_streak

local territory_control_rounds = require("single_game.resolver.helpers.territory_control_rounds")

local M = {}

--- @param state table
--- @param owner string
--- @return nil
function M.apply(state, owner)
	local streak = territory_control_rounds.placement_streak_snapshot(state)
	local delta = territory_control_rounds.plus_mult_delta_for_streak(streak, state, owner)
	if delta ~= 0 then
		state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + delta
	end
end

return M
