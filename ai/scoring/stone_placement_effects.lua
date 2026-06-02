--- Read-only stone placement effect resolution (mirrors resolver placement compile path).
--- @module ai.scoring.stone_placement_effects

local content = require("content")
local effect_registry = require("effect_registry")

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
--- @return table
local IMMEDIATE_PLACEMENT_EFFECT_NAMES = {
	add_points = true,
	add_mult = true,
}

local function resolved_from_effect_defs(stone_def)
	local out = {}
	if not stone_def.effects then
		return out
	end
	for i = 1, #stone_def.effects do
		local effect = stone_def.effects[i]
		if IMMEDIATE_PLACEMENT_EFFECT_NAMES[effect.effect_name] then
			local resolved = effect_registry.stones.resolve(effect)
			if resolved then
				out[#out + 1] = resolved
			end
		end
	end
	return out
end

--- @param stone_def table
--- @param state table
--- @param actor "black"|"white"
--- @return table
function M.resolved_stone_effects_from_def(stone_def, state, actor)
	if not stone_def then
		return {}
	end
	if type(stone_def.behavior) == "function" then
		return resolved_from_behavior(stone_def, state, actor)
	end
	return resolved_from_effect_defs(stone_def)
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

--- @param resolved_effects table
--- @return table
function M.round_effect_defs(resolved_effects)
	local round = {}
	for i = 1, #resolved_effects do
		local r = resolved_effects[i]
		if r.type == "ADD_POINTS" then
			round[i] = {
				effect_name = "add_points",
				macro = "playing_stones",
				sub = "points",
				value = r.value,
				priority = r.priority or 10,
			}
		elseif r.type == "ADD_MULT" then
			round[i] = {
				effect_name = "add_mult",
				macro = "playing_stones",
				sub = "mult",
				value = r.value,
				priority = r.priority or 10,
			}
		end
	end
	return round
end

return M
