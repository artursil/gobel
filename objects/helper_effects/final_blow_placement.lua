--- Final-round placement payout; non-final rounds grant fallback points only.
--- @module objects.helper_effects.final_blow_placement

local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_helpers")

local M = {}

--- @param state table
--- @param owner string
--- @return nil
function M.apply(state, owner)
	if helpers.is_final_round(state) then
		state.scores.points[owner] = state.scores.points[owner] + stone_params.final_blow_points
		state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + stone_params.final_blow_plus_mult
		return
	end
	state.scores.points[owner] = state.scores.points[owner] + stone_params.final_blow_nonfinal_points
end

return M
