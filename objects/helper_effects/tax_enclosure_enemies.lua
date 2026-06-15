--- End-of-turn tax from enemy stones inside the innermost owner enclosure containing this tax stone.
--- @module objects.helper_effects.tax_enclosure_enemies

local config = require("config")
local enclosure = require("single_game.resolver.enclosure")
local stone_params = require("objects.parameters.stones")
local helpers = require("objects.effects_helpers")

local M = {}

--- @param state table
--- @param owner string
--- @param row integer
--- @param col integer
--- @param value table|nil
--- @return nil
function M.apply(state, owner, row, col, value)
	local active_owner = helpers.active_end_of_turn_owner(state)
	if not active_owner or owner ~= active_owner then
		return
	end
	local wall = enclosure.innermost_wall_containing(state.board, row, col, owner)
	if not wall then
		return
	end
	local region_key = enclosure.wall_region_key(wall)
	state._tax_enclosure_paid = state._tax_enclosure_paid or {}
	if state._tax_enclosure_paid[region_key] then
		return
	end
	state._tax_enclosure_paid[region_key] = true
	local enemy_count = enclosure.count_enemy_stones_in_wall(state.board, wall, owner)
	if enemy_count <= 0 then
		return
	end
	local money_per = (value and value.money_per_enemy) or stone_params.tax_money_per_enemy
	local points_per = (value and value.points_per_enemy) or stone_params.tax_points_per_enemy
	local side = owner == config.OWNER_BLACK and "black" or "white"
	local player = require("match_state").player_for_color(state, side)
	player.resources.money = (player.resources.money or 0) + enemy_count * money_per
	state.scores.points[owner] = state.scores.points[owner] + enemy_count * points_per
end

return M
