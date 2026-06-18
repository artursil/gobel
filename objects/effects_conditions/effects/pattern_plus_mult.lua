--- Add plus_mult when newly completed plus patterns appear.
--- @module objects.effects_conditions.effects.pattern_plus_mult

local board = require("board")
local config = require("config")
local shape_patterns = require("game.patterns.shape_patterns")
local animations = require("objects.animations")
local stone_params = require("objects.parameters.stones")
local scheduling = require("objects.effects_conditions.scheduling")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local pattern_helpers = require("objects.effects_conditions.helpers.shared.pattern_placement")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "PATTERN_PLUS_MULT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.mult,
		priority = effect.priority or stone_params.pattern_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
			local board_after = state.board
			local board_before = pattern_helpers.board_before_last_placement(state)
			local newly_completed = shape_patterns.detect_newly_completed_plus_patterns(board_before, board_after, color)
			local place_r, place_c = helpers.placement_coords(state)
			local placed_plus = false
			if place_r and place_c then
				local placed = board_after[place_r][place_c]
				placed_plus = placed and not board.is_empty(placed) and placed.kind == "plus_stone"
			end
			local to_score = {}
			for i = 1, #newly_completed do
				local pattern = newly_completed[i]
				local dedupe = "plus:" .. pattern.center_row .. ":" .. pattern.center_col .. ":" .. pattern.tier .. ":" .. owner
				if not pattern_helpers.pattern_key_seen(state, dedupe) then
					to_score[#to_score + 1] = pattern
				end
			end
			local bonus = pattern_helpers.plus_mult_bonus_for_newly_completed_patterns(
				state,
				board_after,
				to_score,
				owner,
				place_r,
				place_c,
				placed_plus
			)
			if bonus > 0 then
				state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + bonus
			end
			for pi = 1, #to_score do
				local pattern = to_score[pi]
				animations.add_animation("pattern_plus_celebrate")(state, {
					owner = owner,
					cells = pattern.cells,
					board_after = board_after,
				})
			end
		end,
	}
end

return M
