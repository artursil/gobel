--- Gates copper threshold plus_mult when owner already had enough coppers before placement.
--- @module objects.effects_conditions.conditions.owner_coppers_on_board_at_least

local stone_params = require("objects.parameters.stones")
local copper_stones = require("objects.effects_conditions.helpers.shared.copper_stones")

local M = {}

--- Return pass when owner copper count before placement meets the configured threshold.
function M.eval(state, owner, condition_def)
	if not state then
		return false, nil
	end
	local threshold = condition_def and condition_def.value
	if threshold == nil then
		threshold = stone_params.copper_threshold
	end
	local events = state.round_stone_effects or {}
	local stone_event = events[#events]
	if not stone_event or not stone_event.row or not stone_event.col then
		return false, nil
	end
	local before_count = copper_stones.count_owner_copper_on_board(
		state.board,
		stone_event.owner,
		stone_event.row,
		stone_event.col
	)
	if before_count >= threshold then
		return true, nil
	end
	return false, nil
end

return M
