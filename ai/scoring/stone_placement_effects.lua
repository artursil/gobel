--- Read-only stone placement effect resolution (mirrors resolver placement compile path).
--- @module ai.scoring.stone_placement_effects

local content = require("content")
local placement_preview = require("objects.placement_preview")
local placement_round = require("objects.placement_round")
local resolved_type_registry = require("objects.resolved_type_registry")

local M = {}

--- @param side "black"|"white"
--- @return string
local function owner_for_side(side)
	if side == "white" then
		return require("config").OWNER_WHITE
	end
	return require("config").OWNER_BLACK
end

--- @param stone_def table
--- @param state table
--- @param actor "black"|"white"
--- @return table
function M.resolved_stone_effects_from_def(stone_def, state, actor)
	if not stone_def then
		return {}
	end
	local ctx = {
		state = state,
		actor = actor,
		owner = owner_for_side(actor),
		row = nil,
		col = nil,
		board_snapshot = state.board,
	}
	return placement_preview.resolve_from_stone_def(stone_def, ctx)
end

--- @param stone_id string
--- @param state table
--- @param actor "black"|"white"
--- @return table
function M.resolved_for_stone_id(stone_id, state, actor)
	local stone_def = content.resolve_stone(stone_id)
	return M.resolved_stone_effects_from_def(stone_def, state, actor)
end

--- @param stone_ref string|table
--- @param state table
--- @param actor "black"|"white"
--- @return table
function M.resolved_for_stone_ref(stone_ref, state, actor)
	local stone_def = content.resolve_stone(stone_ref)
	return M.resolved_stone_effects_from_def(stone_def, state, actor)
end

--- @param stone_def table
--- @return table
function M.placement_round_defs(stone_def)
	return placement_round.collect_defs(stone_def)
end

--- @param resolved_effects table
--- @param stone_def table|nil
--- @return table
function M.round_effect_defs(resolved_effects, stone_def)
	local round = resolved_type_registry.round_effect_defs_from_resolved(resolved_effects)
	if stone_def then
		return placement_round.merge_round_defs(stone_def, round)
	end
	return round
end

--- Re-export for registry parity tests.
--- @return string[]
function M.immediate_placement_effect_name_keys()
	return placement_preview.immediate_placement_effect_name_keys()
end

return M
