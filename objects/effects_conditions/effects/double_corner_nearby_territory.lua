--- Add territory value in corner 3x3 area around corner tower stone.
--- @module objects.effects_conditions.effects.double_corner_nearby_territory

local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")
local stone_params = require("objects.parameters.stones")
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	return {
		type = "DOUBLE_CORNER_NEARBY_TERRITORY",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.territory,
		priority = effect.priority or 10,
		conditions = effect.conditions or {},
		apply = function(state, _owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			local row = kwargs.row
			local col = kwargs.col
			local n = config.BOARD_SIZE
			local is_corner = (row == 1 or row == n) and (col == 1 or col == n)
			if not is_corner then
				return
			end
			state.territory_value = state.territory_value or {}
			local r0, r1, c0, c1
			if row == 1 and col == 1 then
				r0, r1, c0, c1 = 1, math.min(3, n), 1, math.min(3, n)
			elseif row == 1 and col == n then
				r0, r1, c0, c1 = 1, math.min(3, n), math.max(1, n - 2), n
			elseif row == n and col == 1 then
				r0, r1, c0, c1 = math.max(1, n - 2), n, 1, math.min(3, n)
			else
				r0, r1, c0, c1 = math.max(1, n - 2), n, math.max(1, n - 2), n
			end
			for tr = r0, r1 do
				state.territory_value[tr] = state.territory_value[tr] or {}
				for tc = c0, c1 do
					if tr ~= row or tc ~= col then
						local cur = state.territory_value[tr][tc] or 1
						state.territory_value[tr][tc] = cur + stone_params.stone_tower_corner_territory_add
					end
				end
			end
		end,
	}
end

return M
