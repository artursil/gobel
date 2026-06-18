--- Gates wall stone payout when the placed wall completes at least one point block.
---
--- Evaluated before `wall_stone` apply during the on-play points pass. Uses shared
--- `wall_group_blocks` to count full blocks in the orthogonal connected group at the
--- placement cell. Returns `{ blocks = n }` when `n > 0`; otherwise fails and apply is
--- skipped.
---
--- Condition row params: none required.
---
--- @module objects.effects_conditions.conditions.wall_part_of_wall

local wall_group_blocks = require("objects.effects_conditions.helpers.shared.wall_group_blocks")

local M = {}

--- Return pass and kwargs fragment with completed block count for wall stone apply.
--- @param state table
--- @param owner string
--- @param _condition_def table|nil
--- @return boolean pass
--- @return table|nil fragment
function M.eval(state, owner, _condition_def)
	local blocks = wall_group_blocks.blocks_at_placement(state, owner)
	if blocks <= 0 then
		return false, nil
	end
	return true, { blocks = blocks }
end

return M
