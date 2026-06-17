--- Builds resolved effect tables with ``action`` / ``phase`` metadata from definition stubs.
--- @module objects.effect_factory

local effect_enums = require("objects.effect_enums")
local effect_schedule = require("objects.effect_schedule")

local M = {}

--- @param effect_def table
--- @param opts table { type: string, default_priority?: integer, default_action?: string, default_macro?: string, default_phase?: string, apply?: function, on_tick?: function, extra?: table }
--- @return table
function M.build(effect_def, opts)
	local action, phase = effect_schedule.parse_action_phase(effect_def)
	phase = phase or effect_def.phase or opts.default_phase or effect_enums.PHASE.points
	action = action
		or effect_enums.normalize_action(effect_def.action or effect_def.macro or opts.default_action or opts.default_macro)
		or effect_enums.ACTION.on_play
	local resolve_macro = effect_schedule.action_to_resolve_macro(action)
	local resolved = {
		type = opts.type,
		action = action,
		phase = phase,
		macro = resolve_macro,
		priority = effect_def.priority or opts.default_priority or 10,
		conditions = effect_def.conditions,
		apply = opts.apply,
		on_tick = opts.on_tick,
	}
	if opts.extra then
		for key, value in pairs(opts.extra) do
			resolved[key] = value
		end
	end
	return resolved
end

return M
