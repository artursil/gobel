local config = require("config")

local M = {}

local function stone_key(row, col)
	return row * 100 + col
end

function M.add_points(effect)
	return {
		type = "ADD_POINTS",
		phase = effect.phase or "points",
		value = effect.value,
		priority = effect.priority or 10,
	}
end

function M.add_mult(effect)
	return {
		type = "ADD_MULT",
		phase = effect.phase or "mult",
		value = effect.value,
		priority = effect.priority or 10,
	}
end

function M.distance_bonus(effect)
	return {
		type = "DISTANCE_BONUS",
		phase = "distance",
		value = effect.value,
		priority = effect.priority or 10,
	}
end

function M.resolve(effect)
	local builder = M[effect.effect_name]
	if not builder then
		return nil
	end
	return builder(effect)
end

--- Emits distance-phase effects for one concrete stone instance on the board.
--- The resulting effects precompute `state.distance_modifiers.by_stone[stone_key][tile_key] = bonus`.
--- @param stone_cell table
--- @param row integer
--- @param col integer
--- @param state table
--- @return table array of effect entries
--- Doubles the territory value of the 8 tiles surrounding the stone if it sits in a corner.
--- @param row integer
--- @param col integer
--- @param _effect_def table
--- @return table
function M.double_corner_nearby_territory(row, col, _effect_def)
	local n = config.BOARD_SIZE
	return {
		phase = "territory",
		priority = 10,
		apply = function(state)
			local is_corner = (row == 1 or row == n) and (col == 1 or col == n)
			if not is_corner then
				return
			end
			state.territory_value = state.territory_value or {}
			for dr = -1, 1 do
				for dc = -1, 1 do
					if dr ~= 0 or dc ~= 0 then
						local tr, tc = row + dr, col + dc
						if tr >= 1 and tr <= n and tc >= 1 and tc <= n then
							state.territory_value[tr] = state.territory_value[tr] or {}
							state.territory_value[tr][tc] = 2
						end
					end
				end
			end
		end,
	}
end

local BOARD_EFFECT_BUILDERS = {
	double_corner_nearby_territory = function(row, col, effect_def)
		return M.double_corner_nearby_territory(row, col, effect_def)
	end,
}

local function apply_distance_bonus_for_stone(stone_def, current_state, key, n, distance_bonus_value)
	current_state.distance_modifiers = current_state.distance_modifiers
		or {
			default_bonus = 0,
			by_stone = {},
			get_bonus = nil,
		}
	current_state.distance_modifiers.by_stone = current_state.distance_modifiers.by_stone or {}
	local by_tile = {}
	for tr = 1, n do
		for tc = 1, n do
			by_tile[tr * 100 + tc] = distance_bonus_value
		end
	end
	current_state.distance_modifiers.by_stone[key] = by_tile
end

function M.resolve_board_stone(stone_cell, row, col, state)
	local content = require("content")
	local stone_def = content.get_stone(stone_cell.kind)
	local key = stone_key(row, col)
	local n = config.BOARD_SIZE
	local out = {}

	if stone_def and stone_def.effects then
		for _, effect_def in ipairs(stone_def.effects) do
			if effect_def.effect_name == "distance_bonus" then
				out[#out + 1] = {
					phase = "distance",
					priority = effect_def.priority or 10,
					apply = function(current_state)
						apply_distance_bonus_for_stone(
							stone_def,
							current_state,
							key,
							n,
							effect_def.value
						)
					end,
				}
			elseif effect_def.effect_name == "double_corner_nearby_territory" then
				local builder = BOARD_EFFECT_BUILDERS[effect_def.effect_name]
				if builder then
					out[#out + 1] = builder(row, col, effect_def)
				end
			end
		end
	end

	return out
end

return M
