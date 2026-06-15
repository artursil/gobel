--- Macro/sub scoring phases for per-action resolve passes.
--- Macros: when in the match lifecycle. Subs: territory, points, mult (mult applies plus_mult then x_mult by priority).
--- @module resolver.scoring_phases

local effect_schedule = require("objects.effect_schedule")

local M = {}

M.MACRO_ORDER = {
	"game_start",
	"before_turn",
	"playing_cards",
	"playing_stones",
	"end_of_turn",
	"on_removed",
	"game_end",
}

M.SUB_ORDER = { "territory", "points", "mult" }

M.TERRITORY_STEP_DISTANCE = "distance"
M.TERRITORY_STEP_VALUE = "value"
M.TERRITORY_STEP_OVERRIDE = "override"

M.BOARD_TERRITORY_EFFECT_NAMES = {
	distance_bonus = true,
	double_corner_nearby_territory = true,
	enclosure_territory_multiply = true,
	control_territory_override = true,
}

--- Board stones reapply these on every territory recalc; ``macro`` on the def is ignored.
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

--- @param macro string|nil
--- @return boolean
function M.is_valid_macro(macro)
	if not macro then
		return false
	end
	for i = 1, #M.MACRO_ORDER do
		if M.MACRO_ORDER[i] == macro then
			return true
		end
	end
	return false
end

--- @param sub string|nil
--- @return boolean
function M.is_valid_sub(sub)
	return sub == "territory" or sub == "points" or sub == "mult"
end

--- Legacy ``phase`` string to macro, sub, optional territory internal step.
--- @param effect_def table
--- @return string|nil macro
--- @return string|nil sub
--- @return string|nil territory_step
function M.parse_effect_phase(effect_def)
	if not effect_def then
		return nil, nil, nil
	end
	if effect_def.when and effect_def.phase then
		local macro = effect_schedule.when_to_resolve_macro(effect_def.when)
		return macro, effect_def.phase, effect_def.territory_step
	end
	if effect_def.macro and effect_def.sub then
		return effect_def.macro, effect_def.sub, effect_def.territory_step
	end
	local legacy = effect_def.phase
	if legacy == "distance" then
		return "playing_stones", "territory", M.TERRITORY_STEP_DISTANCE
	end
	if legacy == "territory" then
		return "playing_stones", "territory", M.TERRITORY_STEP_VALUE
	end
	if legacy == "points" then
		return effect_def._legacy_macro or "playing_stones", "points", nil
	end
	if legacy == "mult" then
		return effect_def._legacy_macro or "playing_stones", "mult", nil
	end
	return nil, nil, nil
end

--- @param effect_def table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil when active_sub is territory
--- @return boolean
function M.matches(effect_def, active_macro, active_sub, territory_step)
	local macro, sub, step = M.parse_effect_phase(effect_def)
	if not macro or not sub then
		return false
	end
	if sub ~= active_sub then
		return false
	end
	if active_sub == "territory" and M.is_board_territory_effect(effect_def) then
		if territory_step and step and step ~= territory_step then
			return false
		end
		if territory_step and not step then
			return false
		end
		return true
	end
	if macro ~= active_macro then
		return false
	end
	if active_sub == "territory" and territory_step and step and step ~= territory_step then
		return false
	end
	if active_sub == "territory" and territory_step and not step then
		return false
	end
	return true
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
