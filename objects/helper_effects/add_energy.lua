--- Placement helper: grants energy to the placing owner (clamped to max).
--- @module objects.helper_effects.add_energy

local helpers = require("objects.effects_helpers")

local M = {}

--- @param state table
--- @param owner string
--- @param value number
--- @return nil
function M.apply(state, owner, value)
	helpers.gain_player_energy(state, owner, value)
end

return M
