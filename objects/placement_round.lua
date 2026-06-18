--- Placement record helpers: collect stone effect defs for ``round_stone_effects``.
--- @module objects.placement_round

local effect_schedule = require("objects.effects_conditions.scheduling")
local placement_preview = require("objects.placement_preview")

local M = {}

--- @param effect_def table|nil
--- @return boolean
function M.is_placement_record(effect_def)
	return effect_schedule.is_placement_record(effect_def)
end

--- @param stone_def table|nil
--- @return table effect definition rows for ``round_stone_effects``
function M.collect_defs(stone_def)
	local out = {}
	if not stone_def or not stone_def.effects then
		return out
	end
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		if M.is_placement_record(effect_def)
			and not placement_preview.is_immediate_placement_effect(effect_def) then
			out[#out + 1] = effect_def
		end
	end
	return out
end

--- @param stone_def table|nil
--- @param placement_round table round effect defs from immediate resolved effects
--- @return table merged round effect defs
function M.merge_round_defs(stone_def, placement_round)
	local merged = {}
	for i = 1, #(placement_round or {}) do
		merged[#merged + 1] = placement_round[i]
	end
	local placement_defs = M.collect_defs(stone_def)
	for i = 1, #placement_defs do
		merged[#merged + 1] = placement_defs[i]
	end
	return merged
end

return M
