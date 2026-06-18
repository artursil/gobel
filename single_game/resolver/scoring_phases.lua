--- Action/phase scoring passes for per-action resolve.
--- @module resolver.scoring_phases

local effect_enums = require("objects.effects_conditions.scheduling")
local effect_schedule = require("objects.effects_conditions.scheduling")

local M = {}

M.ACTION_ORDER = effect_enums.ACTION_ORDER
M.PHASE_ORDER = effect_enums.PHASE_ORDER

M.TERRITORY_STEP_DISTANCE = "distance"
M.TERRITORY_STEP_VALUE = "value"
M.TERRITORY_STEP_OVERRIDE = "override"

M.BOARD_TERRITORY_EFFECT_NAMES = {
	distance_bonus = true,
	double_corner_nearby_territory = true,
	enclosure_territory_multiply = true,
	control_territory_override = true,
}

--- Board stones reapply these on every territory recalc; ``action`` on the def is ignored.
--- @param effect_def table|nil
--- @return boolean
function M.is_board_territory_effect(effect_def)
	if not effect_def then
		return false
	end
	if effect_def.territory_scope == "board" then
		return true
	end
	return M.BOARD_TERRITORY_EFFECT_NAMES[effect_def.effect_name] == true
end

--- @param action string|nil canonical action or legacy when alias
--- @return boolean
function M.is_valid_action(action)
	return effect_enums.is_valid_action(effect_enums.normalize_action(action))
end

--- @param phase string|nil
--- @return boolean
function M.is_valid_phase(phase)
	return effect_enums.is_valid_phase(phase)
end

--- @param effect_def table
--- @return string|nil action canonical action
--- @return string|nil phase
--- @return string|nil territory_step
function M.parse_effect_scheduling(effect_def)
	if not effect_def then
		return nil, nil, nil
	end
	local action, phase = effect_schedule.parse_action_phase(effect_def)
	if not action or not phase then
		return nil, nil, nil
	end
	if effect_def.phase == "distance" and not effect_def.action and not effect_def.when then
		return effect_enums.ACTION.on_play, effect_enums.PHASE.territory, M.TERRITORY_STEP_DISTANCE
	end
	if effect_def.phase == "territory" and not effect_def.action and not effect_def.when then
		local step = effect_def.territory_step or M.TERRITORY_STEP_VALUE
		return effect_enums.ACTION.on_play, effect_enums.PHASE.territory, step
	end
	return action, phase, effect_def.territory_step
end

--- @param effect_def table
--- @param active_action string canonical action or legacy when alias
--- @param active_phase string
--- @param territory_step string|nil when active_phase is territory
--- @return boolean
function M.matches(effect_def, active_action, active_phase, territory_step)
	return effect_schedule.matches_resolve_pass(
		effect_def,
		active_action,
		active_phase,
		territory_step,
		M.is_board_territory_effect
	)
end

--- On-place point/mult effects must not run from board scan.
--- @param effect_def table
--- @return boolean
function M.is_placement_lifecycle(effect_def)
	return effect_schedule.is_placement_record(effect_def)
end

--- Board scan must skip placement-record effects.
--- @param effect_def table
--- @return boolean
function M.skips_board_scan(effect_def)
	return effect_schedule.skips_board_scan(effect_def)
end

return M
