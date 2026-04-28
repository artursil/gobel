--- Stone content definitions: placement payloads and default `behavior` producers.
--- @module stones.definitions

local Effects = require("effect_registry")

local M = {}

--- @param stone_def table
--- @return table
local function resolve_placement_effects(stone_def)
	local out = {}
	for i = 1, #stone_def.placement_effects do
		out[i] = Effects.stones.resolve(stone_def.placement_effects[i])
	end
	return out
end

--- @param stone_def table
--- @return function
local function default_stone_behavior(stone_def)
	return function(_state, _actor)
		return resolve_placement_effects(stone_def)
	end
end

M.stone_basic = {
	id = "stone_basic",
	name = "Basic Stone",
	description = "Steady placement stone that adds 1 point on placement.",
	depiction = "Solid circle core",
	graphic = { draw_key = "solid" },
	placement_effects = {
		{ effect_name = "add_points", value = 1, priority = 10 },
	},
}
M.stone_power = {
	id = "stone_power",
	name = "Power Stone",
	description = "Heavy placement stone that adds 2 points on placement.",
	depiction = "Diamond center mark",
	graphic = { draw_key = "diamond" },
	placement_effects = {
		{ effect_name = "add_points", value = 2, priority = 10 },
	},
}
M.stone_focus = {
	id = "stone_focus",
	name = "Focus Stone",
	description = "Precision stone that adds 1 multiplier on placement.",
	depiction = "Ring with dot center",
	graphic = { draw_key = "ring" },
	placement_effects = {
		{ effect_name = "add_mult", value = 1, priority = 10 },
	},
}

M.stone_basic.behavior = default_stone_behavior(M.stone_basic)
M.stone_power.behavior = default_stone_behavior(M.stone_power)
M.stone_focus.behavior = default_stone_behavior(M.stone_focus)

return M
