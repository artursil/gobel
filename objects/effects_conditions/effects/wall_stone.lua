--- Wall stone placement points when the orthogonal connected group completes wall blocks.
---
--- Runs on `on_play` in the `points` phase after a wall stone is committed. The stone
--- definition pairs this effect with the `wall_part_of_wall` condition, which supplies
--- `{ blocks }` via shared `wall_group_blocks` math. This module adds points and queues
--- the wall bounce animation for the full connected group.
---
--- Definition fields: `priority` defaults to `stone_params.wall_effect_priority`;
--- `conditions` must include `wall_part_of_wall`. No `value` or duration fields.
---
--- Kwargs: `blocks` (required) — count of completed wall point blocks in the group.
---
--- Shared helpers: `require_kwargs`, `effects_helpers.placement_coords`,
--- `shape_patterns.group_connected`, `animations.add_animation`.
---
--- No-op: zero or negative points after scaling; missing placement coordinates.
--- @module objects.effects_conditions.effects.wall_stone

local animations = require("objects.animations")
local shape_patterns = require("game.patterns.shape_patterns")
local scheduling = require("objects.effects_conditions.scheduling")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local stone_params = require("objects.parameters.stones")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

--- Build resolved wall stone effect with inline apply.
--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "WALL_STONE",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.wall_effect_priority,
		value = effect.value,
		params = effect.params or {},
		duration = effect.duration,
		scope = effect.scope or "game",
		probability = effect.probability,
		conditions = effect.conditions or {},
		target = effect.target or {
			selector = "self",
			filters = {},
		},
		tags = effect.tags or {},
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "blocks" })
			local points = kwargs.blocks * stone_params.wall_points_per_block
			if points <= 0 then
				return
			end
			state.scores.points[owner] = state.scores.points[owner] + points
			local row, col = helpers.placement_coords(state)
			if not row or not col then
				return
			end
			local group = shape_patterns.group_connected(state.board, row, col)
			animations.add_animation("wall_stone_bounce")(state, {
				owner = owner,
				cells = group,
				bonus = points,
				anchor_row = row,
				anchor_col = col,
			})
		end,
	}
end

return M
