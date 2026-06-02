--- Stone definition resolution: effect deltas and level merging.
--- @module objects.stone_resolve

local M = {}

--- @param effects table[]|nil
--- @return table[]
local function copy_effects(effects)
	local out = {}
	if not effects then
		return out
	end
	for i = 1, #effects do
		local row = effects[i]
		local copy = {}
		for k, v in pairs(row) do
			copy[k] = v
		end
		out[i] = copy
	end
	return out
end

--- Shallow-copy effect rows; add delta when effect_name, macro, and sub match.
--- @param effects table[]
--- @param deltas table<string, { macro: string, sub: string, delta: number }>|nil
--- @return table[]
function M.apply_effect_deltas(effects, deltas)
	if not effects then
		return {}
	end
	if not deltas then
		return copy_effects(effects)
	end
	local out = {}
	for i = 1, #effects do
		local row = effects[i]
		local copy = {}
		for k, v in pairs(row) do
			copy[k] = v
		end
		local delta = deltas[copy.effect_name]
		if delta and delta.macro == copy.macro and delta.sub == copy.sub and type(copy.value) == "number" then
			copy.value = copy.value + (delta.delta or 0)
		end
		out[i] = copy
	end
	return out
end

--- @param def table
--- @return table
function M.copy_stone_def(def)
	local out = {}
	for k, v in pairs(def) do
		if k ~= "effects" and k ~= "upgrade_levels" then
			out[k] = v
		end
	end
	out.effects = copy_effects(def.effects)
	return out
end

--- Cumulative merge: applies upgrade_levels[2]..upgrade_levels[level] in order.
--- Missing tier entries contribute no deltas; levels above max_level are clamped by caller.
--- @param def table
--- @param level integer
--- @return table
function M.resolve_stone_def_at_level(def, level)
	local resolved = M.copy_stone_def(def)
	local max_level = def.max_level or 1
	local clamped = math.max(1, math.min(level, max_level))
	for l = 2, clamped do
		local tier = def.upgrade_levels and def.upgrade_levels[l]
		if tier and tier.effect_deltas then
			resolved.effects = M.apply_effect_deltas(resolved.effects, tier.effect_deltas)
		end
	end
	resolved._level = clamped
	return resolved
end

return M
