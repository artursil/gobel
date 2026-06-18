--- Gates wall stone payout when the placement completes at least one wall block.
--- @module objects.effects_conditions.helpers.conditions.wall_part_of_wall

local wall_group_blocks = require("objects.effects_conditions.helpers.shared.wall_group_blocks")

local M = {}

--- Return pass and kwargs fragment with completed block count for wall stone apply.
function M.eval(state, owner, _condition_def)
	local blocks = wall_group_blocks.blocks_at_placement(state, owner)
	if blocks <= 0 then
		return false, nil
	end
	return true, { blocks = blocks }
end

return M
