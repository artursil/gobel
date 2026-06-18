--- Blockade end-of-turn shrink: decrement ``placement_blocks`` zone timers.
---
--- Runs on ``action = tick`` globally at end of turn (even turns when no blockade was
--- registered this action). Uses ``placement_blocks`` board-zone exception — not
--- ``cell.duration_left`` on the blockade stone.
---
--- Invoked from ``resolve_round`` EOT pipeline, not per-cell board scan.
---
--- Shared helpers: ``blocked_cells.tick``.
---
--- @module objects.effects_conditions.effects.blockade_tick

local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")

local M = {}

--- @param effect table
--- @return table
function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "BLOCKADE_TICK",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.tick,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or stone_params.default_effect_priority,
		conditions = effect.conditions or {},
		apply = function(state, _owner, _kwargs)
			require("single_game.resolver.helpers.blocked_cells").tick(state)
		end,
	}
end

return M
