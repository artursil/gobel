--- Builds resolved effect tables with ``when`` / ``phase`` metadata from definition stubs.
--- @module objects.effect_factory

local effect_schedule = require("objects.effect_schedule")

local M = {}

--- @param effect_def table
--- @param opts table { type: string, default_priority?: integer, default_macro?: string, default_sub?: string, apply?: function, on_tick?: function, extra?: table }
--- @return table
function M.build(effect_def, opts)
	local when, phase = effect_schedule.parse_when_phase(effect_def)
	local sub = phase or effect_def.sub or effect_def.phase or opts.default_sub or "points"
	local resolved = {
		type = opts.type,
		when = when,
		phase = sub,
		macro = effect_def.macro
			or opts.default_macro
			or (when and effect_schedule.when_to_resolve_macro(when)),
		sub = sub,
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
