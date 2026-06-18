--- Add or deduct money for the current owner.
--- @module objects.effects_conditions.effects.add_money

local config = require("config")
local scheduling = require("objects.effects_conditions.scheduling")

local M = {}

function M.build(effect)
	local action, phase = scheduling.parse_action_phase(effect)
	local amount = (effect.value or {}).amount or 0
	return {
		type = "ADD_MONEY",
		effect_name = effect.effect_name,
		action = action or scheduling.ACTION.on_play,
		phase = phase or scheduling.PHASE.points,
		priority = effect.priority or 10,
		value = effect.value or {},
		conditions = effect.conditions or {},
		apply = function(state, owner, _kwargs)
			local side = owner == config.OWNER_BLACK and "black" or "white"
			local player = require("match_state").player_for_color(state, side)
			player.resources.money = math.max(0, (player.resources.money or 0) + amount)
		end,
	}
end

return M
