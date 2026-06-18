--- Multiply x_mult when newly completed X patterns appear.
--- @module objects.effects_conditions.effects.pattern_x_mult

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
		type = "PATTERN_X_MULT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.mult,
		priority = effect.priority or stone_params.pattern_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
			local board_after = state.board
			local board_before = pattern_helpers.board_before_last_placement(state)
			local newly_completed = shape_patterns.detect_newly_completed_x_patterns(board_before, board_after, color)
			for i = 1, #newly_completed do
				local pattern = newly_completed[i]
				local dedupe = "x:" .. pattern.center_row .. ":" .. pattern.center_col .. ":" .. pattern.tier .. ":" .. owner
				if not pattern_helpers.pattern_key_seen(state, dedupe) then
					local x_count = shape_patterns.count_x_stones_in_pattern(board_after, pattern)
					local factor = shape_patterns.x_mult_factor_for_x_stone_count(x_count)
					if x_count > 0 then
						state.scores.x_mult[owner] = state.scores.x_mult[owner] * factor
					end
					animations.add_animation("pattern_x_celebrate")(state, {
						owner = owner,
						cells = pattern.cells,
						board_after = board_after,
					})
				end
			end
		end,
	}
end

return M
