--- One full scoring round: default fields, opponent sync, stances, pre/main phases, territory, player totals, timed tick.
--- @module resolver.resolve_round

local config = require("config")
local match_state = require("match_state")
local phases = require("single_game.resolver.phases")
local effect_manager = require("single_game.resolver.effect_manager")
local territory = require("single_game.resolver.territory")
local scoring = require("scoring")

local M = {}

--- @param state table
--- @return nil
local function ensure_state_fields(state)
	state.last_opponent_move = state.last_opponent_move or nil
	state.last_opponent_modifiers = state.last_opponent_modifiers or {}
	state.active_effects = state.active_effects or {}
	state.round_stone_effects = state.round_stone_effects or {}
	state.stances = state.stances or {}
	state.modifiers = state.modifiers or {}
	do
		local n = config.BOARD_SIZE
		state.territory_value = {}
		for r = 1, n do
			state.territory_value[r] = {}
			for c = 1, n do
				state.territory_value[r][c] = 1
			end
		end
	end
	state.distance_modifiers = state.distance_modifiers or {
		default_bonus = 0,
		by_stone = {},
		get_bonus = function(self, stone_key, tile_r, tile_c)
			local by_tile = self.by_stone[stone_key]
			if not by_tile then
				return self.default_bonus
			end
			local tile_key = tile_r * 100 + tile_c
			local v = by_tile[tile_key]
			if v == nil then
				return self.default_bonus
			end
			return v
		end,
	}
	state.last_played_stone = state.last_played_stone or nil
	state.scores = state.scores or {
		turn_bonus = { A = 1, B = 1 },
		territory = { A = 0, B = 0 },
		points = { A = 0, B = 0 },
		plus_mult = { A = 1, B = 1 },
		x_mult = { A = 1, B = 1 },
	}
end

--- @param state table
--- @return nil
local function sync_opponent_state(state)
	state.last_opponent_move = state.last_opponent_move or nil
	state.last_opponent_modifiers = state.last_opponent_modifiers or {}
end

--- @param side string
--- @return string
local function side_to_owner(side)
	if side == "white" then
		return "B"
	end
	return "A"
end

--- Flattens both players’ fixed+swappable poses into `state.poses` with A/B owner.
--- @param state table
--- @return nil
local function rebuild_ordered_stances(state)
	local ordered = {}
	for _, side in ipairs({ "black", "white" }) do
		local player = match_state.player_for_color(state, side)
		for _, stance_id in ipairs(player.stances.fixed or {}) do
			ordered[#ordered + 1] = { type = stance_id, owner = side_to_owner(side) }
		end
		for _, stance_id in ipairs(player.stances.swappable or {}) do
			ordered[#ordered + 1] = { type = stance_id, owner = side_to_owner(side) }
		end
	end
	state.stances = ordered
end

--- Resets point/mult baselines from player bonuses and board `overall_mult`.
--- @param state table
--- @return nil
local function reset_base_scores(state)
	local tn = state.turn_number or 1
	local turn_bonus = 1 + (0.1 * tn)
	
	state.scores.turn_bonus = { A = turn_bonus, B = turn_bonus }
	state.scores.territory = { A = 0, B = 0 }
	state.scores.plus_mult = state.scores.plus_mult or { A = 1, B = 1 }
	state.scores.x_mult = state.scores.x_mult or { A = 1, B = 1 }
	state.scores.points = state.scores.points or { A = 0, B = 0 }
end

--- Pushes `state.scores` into `match_state` player `score` tables and `total`.
--- @param state table
--- @return nil
local function sync_player_scores(state)
	local black = match_state.player_for_color(state, "black")
	local white = match_state.player_for_color(state, "white")
	
	local function calculate_score(turn_bonus, territory, points, plus_mult, x_mult)
		return turn_bonus * territory * points * plus_mult * x_mult
	end
	
	local turn_bonus_a = state.scores.turn_bonus.A
	local territory_a = state.scores.territory.A
	local points_a = state.scores.points.A
	local plus_mult_a = state.scores.plus_mult.A
	local x_mult_a = state.scores.x_mult.A
	local total_a = calculate_score(turn_bonus_a, territory_a, points_a, plus_mult_a, x_mult_a)
	
	local turn_bonus_b = state.scores.turn_bonus.B
	local territory_b = state.scores.territory.B
	local points_b = state.scores.points.B
	local plus_mult_b = state.scores.plus_mult.B
	local x_mult_b = state.scores.x_mult.B
	local total_b = calculate_score(turn_bonus_b, territory_b, points_b, plus_mult_b, x_mult_b)
	
	black.score.turn_bonus = turn_bonus_a
	black.score.territory = territory_a
	black.score.points = points_a
	black.score.plus_mult = plus_mult_a
	black.score.x_mult = x_mult_a
	black.score.total = total_a
	
	white.score.turn_bonus = turn_bonus_b
	white.score.territory = territory_b
	white.score.points = points_b
	white.score.plus_mult = plus_mult_b
	white.score.x_mult = x_mult_b
	white.score.total = total_b
end

--- Decrements `active_effects` remaining turns; drops expired entries.
--- @param state table
--- @return nil
local function tick_timed_effects(state)
	local kept = {}
	for _, active in ipairs(state.active_effects) do
		active.remaining_turns = active.remaining_turns - 1
		if active.remaining_turns > 0 then
			kept[#kept + 1] = active
		end
	end
	state.active_effects = kept
end

--- Main entry: runs full PRE/MAIN pipeline including territory begin/finish and clears `round_stone_effects`.
--- @param state table
--- @return nil
function M.resolve(state)
	ensure_state_fields(state)
	sync_opponent_state(state)
	rebuild_ordered_stances(state)
	reset_base_scores(state)
	for _, phase in ipairs(phases.PRE) do
		effect_manager.apply_phase(state, phase)
	end
	for _, phase in ipairs(phases.MAIN) do
		if phase == "territory" then
			territory.begin_assignment(state)
		end
		effect_manager.apply_phase(state, phase)
		if phase == "territory" then
			territory.finish_assignment(state)
		end
	end
	sync_player_scores(state)
	state.round_stone_effects = {}
	tick_timed_effects(state)
end

return M
