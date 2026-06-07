--- Derives expected test values from ``objects.parameters`` and content definitions.
--- Prefer these helpers over hardcoded numbers so tuning parameters does not break specs.
--- @module spec.parameters_helper

local config = require("config")
local content = require("content")
local shape_patterns = require("game.patterns.shape_patterns")
local card_params = require("objects.parameters.cards")
local stance_params = require("objects.parameters.stances")
local stone_params = require("objects.parameters.stones")

local M = {
	card = card_params,
	stance = stance_params,
	stone = stone_params,
}

--- @return integer
function M.starting_points()
	return 1
end

--- @return integer
function M.base_plus_mult()
	return 1
end

--- @return integer
function M.base_x_mult()
	return 1
end

--- @param turn_number integer|nil
--- @return number
function M.turn_bonus(turn_number)
	return 1 + (0.1 * (turn_number or 1))
end

--- @param turn_number integer|nil
--- @param territory integer
--- @param points integer
--- @param plus_mult number
--- @param x_mult number
--- @return number
function M.total_score(turn_number, territory, points, plus_mult, x_mult)
	return M.turn_bonus(turn_number) * territory * points * plus_mult * x_mult
end

--- @param turn_number integer|nil
--- @param territory integer
--- @param points integer
--- @param plus_mult number
--- @param x_mult number
--- @return integer
function M.rounded_total(turn_number, territory, points, plus_mult, x_mult)
	return math.floor(M.total_score(turn_number, territory, points, plus_mult, x_mult) + 0.5)
end

--- Empty cells owned after one center stone on an otherwise empty board.
--- @return integer
function M.territory_after_single_center_stone()
	return config.BOARD_SIZE * config.BOARD_SIZE - 1
end

--- @param def table|nil
--- @param effect_name string
--- @return number|nil
local function effect_value_from_def(def, effect_name)
	if not def or not def.effects then
		return nil
	end
	for i = 1, #def.effects do
		local effect = def.effects[i]
		if effect.effect_name == effect_name then
			return effect.value
		end
	end
	return nil
end

--- @param card_id string
--- @param effect_name string
--- @return number|nil
function M.card_effect_value(card_id, effect_name)
	return effect_value_from_def(content.get_card(card_id), effect_name)
end

--- @param stone_id string
--- @param effect_name string
--- @return number|nil
function M.stone_effect_value(stone_id, effect_name)
	return effect_value_from_def(content.get_stone(stone_id), effect_name)
end

--- @param card_id string
--- @return number
function M.card_points(card_id)
	return M.card_effect_value(card_id, "add_points") or 0
end

--- @param stone_id string
--- @return number
function M.stone_points(stone_id)
	return M.stone_effect_value(stone_id, "add_points") or 0
end

--- @param stone_id string
--- @return number
function M.stone_plus_mult(stone_id)
	return M.stone_effect_value(stone_id, "add_mult") or 0
end

--- @param card_id string
--- @return string
function M.card_play_message(card_id)
	local def = content.get_card(card_id)
	local label = def.display_name or def.name or "Card"
	local parts = {}
	for i = 1, #(def.effects or {}) do
		local effect = def.effects[i]
		if effect.effect_name == "add_points" then
			parts[#parts + 1] = string.format("+%d points", effect.value)
		elseif effect.effect_name == "add_mult" then
			parts[#parts + 1] = string.format("+%d mult", effect.value)
		end
	end
	return label .. ": " .. table.concat(parts, ", ")
end

--- @param stone_id string
--- @return string
function M.stone_placement_message(stone_id)
	local def = content.get_stone(stone_id)
	local points = M.stone_points(stone_id)
	if points > 0 then
		return string.format("%s placement: +%d points", def.name, points)
	end
	local mult = M.stone_plus_mult(stone_id)
	if mult > 0 then
		return string.format("%s placement: +%d mult", def.name, mult)
	end
	return def.name .. " placed"
end

--- @param connected_stone_count integer
--- @return integer
function M.wall_points(connected_stone_count)
	return shape_patterns.wall_points_for_connected_group_size(connected_stone_count)
end

--- @param capture_count integer
--- @return integer
function M.capture_bonus_points(capture_count)
	return stone_params.capture_bonus_points_per_stone * capture_count
end

--- @return string
function M.wall_points_float_label()
	return string.format("+%d", stone_params.wall_points_per_block)
end

--- @return string
function M.format_x_mult_animation_label(factor)
	if factor == math.floor(factor) then
		return string.format("×%d", factor)
	end
	return string.format("×%.1f", factor)
end

--- Matches ``objects.animations_definitions`` pattern_x_celebrate float text.
--- @return string
function M.x_mult_animation_label()
	return M.format_x_mult_animation_label(stone_params.x_stone_mult_factor)
end

--- @param tier integer
--- @return number
function M.x_mult_factor_for_tier(tier)
	return shape_patterns.x_mult_factor_for_tier(tier)
end

--- Expected tier product: ``factor ^ tier``.
--- @param tier integer
--- @return number
function M.x_mult_tier_product(tier)
	local product = 1
	for _ = 1, tier do
		product = product * stone_params.x_stone_mult_factor
	end
	return product
end

--- @param tier integer
--- @return integer
function M.plus_mult_bonus_for_tier(tier)
	return shape_patterns.plus_mult_bonus_for_tier(tier)
end

--- Matches ``objects.animations_definitions`` pattern_plus_celebrate float text.
--- @return string
function M.plus_stone_animation_label()
	return string.format("+%d", stone_params.plus_stone_mult_add)
end

--- @param x_stone_count integer
--- @return number
function M.x_mult_factor(x_stone_count)
	return shape_patterns.x_mult_factor_for_x_stone_count(x_stone_count)
end

--- @param base number
--- @param x_stone_count integer
--- @return number
function M.x_mult_after(base, x_stone_count)
	return base * M.x_mult_factor(x_stone_count)
end

--- @param plus_stone_count integer
--- @return integer
function M.plus_mult_bonus(plus_stone_count)
	return shape_patterns.plus_mult_bonus_for_plus_stone_count(plus_stone_count)
end

--- @param base number
--- @param plus_stone_count integer
--- @return number
function M.plus_mult_after(base, plus_stone_count)
	return base + M.plus_mult_bonus(plus_stone_count)
end

--- @param base_points number
--- @param connected_stone_count integer
--- @return number
function M.points_after_wall_bonus(base_points, connected_stone_count)
	return base_points + M.wall_points(connected_stone_count)
end

--- @param counter_before integer
--- @return integer
function M.persistent_flux_special_counter_after(counter_before)
	return counter_before + stance_params.stance_persistent_flux_special_delta
end

--- @param counter_before integer
--- @return integer effective pending delta after a wall stone
function M.persistent_flux_wall_effective_delta(counter_before)
	local old = counter_before
	local new_val = math.max(
		stance_params.stance_persistent_flux_counter_floor,
		old + stance_params.stance_persistent_flux_wall_delta
	)
	return new_val - old
end

--- Round 1: full counter applied as plus_mult.
--- @param counter integer
--- @return integer
function M.persistent_flux_round1_plus_mult_delta(counter)
	return counter
end

--- Round 2+: pending delta from special tag stone.
--- @return integer
function M.persistent_flux_special_pending_delta()
	return stance_params.stance_persistent_flux_special_delta
end

--- @param echo_count integer
--- @return integer
function M.persistent_flux_echo_pending_delta(echo_count)
	return stance_params.stance_persistent_flux_special_delta * echo_count
end

--- @param card_id string
--- @param stone_id string|nil
--- @param turn_number integer|nil
--- @return integer
function M.case01_black_total_after_card_and_stone(card_id, stone_id, turn_number)
	local points = M.starting_points() + M.card_points(card_id) + M.stone_points(stone_id or "stone_basic")
	return M.rounded_total(turn_number or 1, M.territory_after_single_center_stone(), points, M.base_plus_mult(), M.base_x_mult())
end

return M
