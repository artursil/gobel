--- Gates capture-stone supplemental removal when an eligible enemy remains after commit.
---
--- Evaluated before ``capture_zero_liberty_enemy`` apply during on-play points. Regular Go
--- captures already ran at commit; remaining enemies at zero empty neighbors are
--- supplemental-eligible. RNG pick returns ``{ row, col }`` for the effect to enqueue.
---
--- Condition row params: none required.
---
--- @module objects.effects_conditions.conditions.capture_stone_supplemental_target

local capture_stone_supplemental = require("objects.effects_conditions.helpers.shared.capture_stone_supplemental")

local M = {}

--- Return pass and supplemental target coordinates when a candidate exists.
--- @param state table
--- @param owner string
--- @param _condition_def table|nil
--- @return boolean pass
--- @return table|nil fragment
function M.eval(state, owner, _condition_def)
	local row, col = capture_stone_supplemental.pick_supplemental_target(state, owner)
	if row == nil or col == nil then
		return false, nil
	end
	return true, { row = row, col = col }
end

return M
