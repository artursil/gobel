--- Shared pattern placement bonus helpers for X and + mult effects.
--- @module objects.effects_conditions.helpers.shared.pattern_placement

local board = require("board")
local config = require("config")
local stone_params = require("objects.parameters.stones")

local M = {}

local function pattern_apply_keys(state)
	state.run_state = state.run_state or {}
	state.run_state.pattern_apply_keys = state.run_state.pattern_apply_keys or {}
	return state.run_state.pattern_apply_keys
end

--- Match-lifetime dedupe for pattern placement bonuses (not cleared each resolve).
function M.pattern_key_seen(state, key)
	if state._retrigger_replay_depth and state._retrigger_replay_depth > 0 then
		return false
	end
	local keys = pattern_apply_keys(state)
	if keys[key] then
		return true
	end
	keys[key] = true
	return false
end

--- Board copy with the last placed stone removed for newly-completed pattern detection.
function M.board_before_last_placement(state)
	local move = state.last_opponent_move
	if not move or not move.row or not move.col then
		return state.board
	end
	local b = board.clone(state.board)
	b[move.row][move.col] = config.STONE_NONE
	return b
end

--- Sum plus_mult bonus for plus_stone cells in newly completed + patterns.
function M.plus_mult_bonus_for_newly_completed_patterns(
	state,
	board_after,
	patterns,
	owner,
	place_r,
	place_c,
	placed_plus
)
	state._pattern_plus_bonus_cells = state._pattern_plus_bonus_cells or {}
	local bonus = 0
	for pi = 1, #patterns do
		local pattern = patterns[pi]
		for ci = 1, #pattern.cells do
			local r, c = pattern.cells[ci][1], pattern.cells[ci][2]
			local cell = board_after[r][c]
			if cell and cell.kind == "plus_stone" then
				local is_placed = placed_plus and place_r == r and place_c == c
				local cell_key = owner .. ":" .. r .. ":" .. c
				if is_placed or not state._pattern_plus_bonus_cells[cell_key] then
					if not is_placed then
						state._pattern_plus_bonus_cells[cell_key] = true
					end
					bonus = bonus + stone_params.plus_stone_mult_add
				end
			end
		end
	end
	return bonus
end

return M
