--- Placement resolve pipeline after board commit (ADR 0001).
--- @module single_game.resolver.placement_pipeline

local remove_stones = require("single_game.resolver.stages.remove_stones")
local legality_of_moves = require("single_game.resolver.stages.legality_of_moves")

local M = {}

--- Step 2: remove stones that should not remain after commit.
--- @param ctx table
--- @return integer extra_captures
--- @return boolean kamikaze_sacrifice_applies
function M.remove_stones(ctx)
	return remove_stones.run(ctx)
end

--- Step 6: refresh cached legal moves.
--- @param state table
--- @return nil
function M.recalculate_legal_moves(state)
	legality_of_moves.run(state)
end

return M
