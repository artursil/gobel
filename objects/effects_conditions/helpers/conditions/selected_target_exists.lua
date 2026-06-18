--- Pass when the effect context includes a selected board target.
--- @module objects.effects_conditions.helpers.conditions.selected_target_exists

local selected_stone = require("objects.effects_conditions.helpers.shared.selected_stone")

local M = {}

--- Require a selected target with coordinates.
function M.eval(state, _owner, _condition_def)
	if selected_stone.target_with_coords(state) then
		return true, nil
	end
	return false, nil
end

return M
