--- Read-only stone placement effect resolution (mirrors resolver placement compile path).
--- @module ai.scoring.stone_placement_effects

local content = require("content")
local effect_registry = require("effect_registry")
local placement_registry = require("objects.placement_effect_registry")

local M = {}

--- @param stone_def table
--- @param state table
--- @param actor "black"|"white"
--- @return table
local function resolved_from_behavior(stone_def, state, actor)
	if type(stone_def.behavior) == "function" then
		return stone_def.behavior(state, actor)
	end
	return {}
end

--- @param stone_def table
--- @param state table
--- @param actor "black"|"white"
--- @param row integer|nil
--- @param col integer|nil
--- @return table
function M.resolved_stone_effects_from_def(stone_def, state, actor, row, col)
	if not stone_def then
		return {}
	end
	if type(stone_def.behavior) == "function" then
		return resolved_from_behavior(stone_def, state, actor)
	end
	return placement_registry.resolved_stone_effects_from_def(
		stone_def,
		state,
		actor,
		row,
		col,
		effect_registry.stones.resolve
	)
end

--- @param stone_id string
--- @param state table
--- @param actor "black"|"white"
--- @param row integer|nil
--- @param col integer|nil
--- @return table
function M.resolved_for_stone_id(stone_id, state, actor, row, col)
	local stone_def = content.resolve_stone(stone_id)
	return M.resolved_stone_effects_from_def(stone_def, state, actor, row, col)
end

--- @param stone_ref string|table
--- @param state table
--- @param actor "black"|"white"
--- @param row integer|nil
--- @param col integer|nil
--- @return table
function M.resolved_for_stone_ref(stone_ref, state, actor, row, col)
	local stone_def = content.resolve_stone(stone_ref)
	return M.resolved_stone_effects_from_def(stone_def, state, actor, row, col)
end

--- @param resolved_effects table
--- @return table
function M.round_effect_defs(resolved_effects)
	return placement_registry.round_effect_defs_from_resolved(resolved_effects)
end

--- Re-export for registry parity tests.
--- @return string[]
function M.immediate_placement_effect_name_keys()
	return placement_registry.immediate_placement_effect_name_keys()
end

return M
