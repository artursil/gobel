--- Shared helpers for gameplay-driven UI animations (no LÖVE). Used by ``objects.animations_definitions`` builders only.
--- Steel-float ms budgets live in ``objects.animations_constants``.
--- @module objects.animations_helper

local animations_constants = require("objects.animations_constants")
local config = require("config")

local M = {}

--- Integer ms per ``hand_card_float_text`` step for steel sync: ``max(min_per_card, floor(target_total / N))``.
--- Uses ``animations_constants`` for target total and per-card floor.
--- @param steel_count integer
--- @return integer
function M.steel_hand_float_step_duration_ms(steel_count)
	local min_ms = animations_constants.STEEL_HAND_FLOAT_MIN_PER_CARD_MS
	local n = steel_count
	if type(n) ~= "number" or n < 1 then
		return min_ms
	end
	n = math.floor(n)
	local divided = math.floor(animations_constants.STEEL_HAND_FLOAT_TARGET_TOTAL_MS / n)
	return math.max(min_ms, divided)
end

--- 1-based index among **that player's** permanent stance slots (panel order), from ``state.resolution``
--- when the active effect is a stance; otherwise ``1``.
--- @param state table
--- @param owner string  ``config.OWNER_BLACK`` | ``config.OWNER_WHITE`` or loose ``"black"`` / ``"white"``
--- @return integer
--- Integer ms per board-stone bounce step in a celebrate sequence.
--- @param cell_count integer
--- @return integer
function M.board_stone_bounce_step_duration_ms(cell_count)
	local min_ms = animations_constants.BOARD_STONE_BOUNCE_STEP_MS
	local n = cell_count
	if type(n) ~= "number" or n < 1 then
		return min_ms
	end
	return min_ms
end

function M.get_stance_index(state, owner)
	local res = state.resolution
	if not res then
		return 1
	end
	local ob, ow = config.OWNER_BLACK, config.OWNER_WHITE
	local want = owner
	if want ~= ob and want ~= ow then
		want = ((owner == "black" or owner == ob) and ob) or ow
	end
	if res.source_owner == want and type(res.source_stance_slot_index) == "number" then
		return res.source_stance_slot_index
	end
	return 1
end

return M
