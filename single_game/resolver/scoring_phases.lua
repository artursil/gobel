--- Macro/sub scoring phases for per-action resolve passes.
--- Macros: when in the match lifecycle. Subs: territory, points, mult (mult applies plus_mult then x_mult by priority).
--- @module resolver.scoring_phases

local M = {}

M.MACRO_ORDER = {
	"game_start",
	"before_turn",
	"playing_cards",
	"playing_stones",
	"end_of_turn",
	"game_end",
}

M.SUB_ORDER = { "territory", "points", "mult" }

M.TERRITORY_STEP_DISTANCE = "distance"
M.TERRITORY_STEP_VALUE = "value"

M.PLACEMENT_ONLY_EFFECT_NAMES = {
	add_points = true,
	add_mult = true,
	add_energy = true,
	mult_control_streak = true,
}

M.BOARD_TERRITORY_EFFECT_NAMES = {
	distance_bonus = true,
	double_corner_nearby_territory = true,
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
function M.is_placement_only_effect_name(effect_name)
	return M.PLACEMENT_ONLY_EFFECT_NAMES[effect_name] == true
end

return M
