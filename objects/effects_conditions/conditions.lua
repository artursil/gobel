--- Thin condition dispatch registry.
--- @module objects.effects_conditions.conditions

local always = require("objects.effects_conditions.conditions.always")
local never = require("objects.effects_conditions.conditions.never")
local random = require("objects.effects_conditions.conditions.random")
local stone_tag_just_added = require("objects.effects_conditions.conditions.stone_tag_just_added")
local temporary_stance_expired = require("objects.effects_conditions.conditions.temporary_stance_expired")
local temporary_stance_active = require("objects.effects_conditions.conditions.temporary_stance_active")
local stance_owner_is_current_turn = require("objects.effects_conditions.conditions.stance_owner_is_current_turn")
local round_number_exactly = require("objects.effects_conditions.conditions.round_number_exactly")
local round_number_at_least = require("objects.effects_conditions.conditions.round_number_at_least")
local selected_target_exists = require("objects.effects_conditions.conditions.selected_target_exists")
local selected_target_is_enemy_stone = require("objects.effects_conditions.conditions.selected_target_is_enemy_stone")
local selected_target_is_friendly_stone = require("objects.effects_conditions.conditions.selected_target_is_friendly_stone")
local owner_coppers_on_board_at_least = require("objects.effects_conditions.conditions.owner_coppers_on_board_at_least")
local wall_part_of_wall = require("objects.effects_conditions.conditions.wall_part_of_wall")
local capture_stone_supplemental_target = require("objects.effects_conditions.conditions.capture_stone_supplemental_target")

local CONDITION_HELPERS = {
	always = always,
	never = never,
	random = random,
	stone_tag_just_added = stone_tag_just_added,
	temporary_stance_expired = temporary_stance_expired,
	temporary_stance_active = temporary_stance_active,
	stance_owner_is_current_turn = stance_owner_is_current_turn,
	round_number_exactly = round_number_exactly,
	round_number_at_least = round_number_at_least,
	selected_target_exists = selected_target_exists,
	selected_target_is_enemy_stone = selected_target_is_enemy_stone,
	selected_target_is_friendly_stone = selected_target_is_friendly_stone,
	owner_coppers_on_board_at_least = owner_coppers_on_board_at_least,
	wall_part_of_wall = wall_part_of_wall,
	capture_stone_supplemental_target = capture_stone_supplemental_target,
}

local M = {}

--- Evaluate one condition definition or condition name string.
function M.eval(first, state, owner)
	if type(first) == "string" then
		local helper = CONDITION_HELPERS[first]
		if not helper then
			return true, nil
		end
		return helper.eval(state, owner, nil)
	end

	local condition_def = first
	if not condition_def then
		return true, nil
	end
	if not condition_def.condition_name then
		return true, nil
	end
	local helper = CONDITION_HELPERS[condition_def.condition_name]
	if not helper then
		return true, nil
	end
	return helper.eval(state, owner, condition_def)
end

--- Evaluate an array of conditions (all must pass).
function M.eval_all(conditions, state, owner)
	if not conditions or #conditions == 0 then
		return true
	end
	for i = 1, #conditions do
		local pass, _ = M.eval(conditions[i], state, owner)
		if not pass then
			return false
		end
	end
	return true
end

return M
