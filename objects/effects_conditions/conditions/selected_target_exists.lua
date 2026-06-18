--- Gate-only condition: pass when resolution includes a selected board target with coordinates.
---
--- Used by destroy and forge card defs as a second apply-time check. Does not supply kwargs;
--- effects read the target from ``state.resolution`` via ``selected_stone`` helpers.
---
--- Condition row params: none required.
---
--- @module objects.effects_conditions.conditions.selected_target_exists

local selected_stone = require("objects.effects_conditions.helpers.shared.selected_stone")

local M = {}

--- Return pass when a selected target with row and col is present.
--- @param state table
--- @param _owner string
--- @param _condition_def table|nil
--- @return boolean pass
--- @return table|nil fragment
function M.eval(state, _owner, _condition_def)
	if selected_stone.target_with_coords(state) then
		return true, nil
	end
	return false, nil
end

return M
