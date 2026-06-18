--- Blockade on-play setup: register opponent placement blocks on adjacent empty cells.
---
--- Runs on ``on_play`` in the ``points`` phase. Durations live in ``placement_blocks``
--- on empty adjacent cells (blockade board-zone exception), not on the blockade stone cell.
---
--- Shared helpers: ``effects_helpers.placement_coords``, ``blocked_cells.register_adjacent_from_blockade``.
---
--- No-op: missing placement coordinates.
--- @module objects.effects_conditions.effects.blockade_adjacent

local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")

local M = {}

--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "BLOCKADE_ADJACENT",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local row, col = helpers.placement_coords(state)
			if row == nil or col == nil then
				return
			end
			local actor = owner == config.OWNER_BLACK and "black" or "white"
			require("single_game.resolver.helpers.blocked_cells").register_adjacent_from_blockade(state, row, col, actor)
			state._blockade_registered_this_action = true
		end,
	}
end

return M
