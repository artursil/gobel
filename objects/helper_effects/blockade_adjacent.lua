--- Block opponent on orthogonally adjacent empty cells for configured duration.
--- @module objects.helper_effects.blockade_adjacent

local config = require("config")
local blocked_cells = require("single_game.resolver.helpers.blocked_cells")
local helpers = require("objects.effects_helpers")

local M = {}

--- @param state table
--- @param owner string
--- @param row integer|nil
--- @param col integer|nil
--- @return nil
function M.apply(state, owner, row, col)
	if row == nil or col == nil then
		row, col = helpers.placement_coords(state)
	end
	if row == nil or col == nil then
		return
	end
	local actor = owner == config.OWNER_BLACK and "black" or "white"
	blocked_cells.register_adjacent_from_blockade(state, row, col, actor)
	state._blockade_registered_this_action = true
end

--- @param state table
--- @return nil
function M.tick(state)
	blocked_cells.tick(state)
end

return M
