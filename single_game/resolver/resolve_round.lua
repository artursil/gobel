--- One full scoring round: default fields, opponent sync, stances, pre/main phases, territory, player totals, timed tick.
---
--- Stance ownership is canonical under ``state.players.*.stances.fixed`` / ``swappable``. Effect collection
--- builds ``state._stance_effect_order`` via ``stance_order.flatten_stances_for_resolve`` (see ``stance_order``
--- module); there is no merged ``state.stances`` array on match state.
---
--- Card effects read **`state.just_played`** (filled by `PLAY_CARD_COMMIT` in the resolver), not hand contents.
--- After scoring, **`card_play_memory.flush_just_played_to_history`** appends to **`state.played_cards`** and clears `just_played`.
--- @module resolver.resolve_round

local config = require("config")
local match_state = require("match_state")
local phases = require("single_game.resolver.phases")
local effect_manager = require("single_game.resolver.effect_manager")
local queries = require("single_game.resolver.state_queries")
local territory = require("single_game.resolver.territory")
local card_play_memory = require("single_game.resolver.card_play_memory")
local dbg = require("debugger")

local M = {}

--- @param state table
--- @return nil
local function ensure_state_fields(state)
	state.round_number = match_state.round_number_from_turn(state.turn_number)
	state.run_state = state.run_state or {}
	state.run_state.pending_counter_mult_delta = {}
	state.last_opponent_move = state.last_opponent_move or nil
	state.last_opponent_modifiers = state.last_opponent_modifiers or {}
	state.active_effects = state.active_effects or {}
	state.round_stone_effects = state.round_stone_effects or {}
	state.temporary_stances = state.temporary_stances or {}
	state.just_played = state.just_played or {}
	state.played_cards = state.played_cards or {}
	state.ui_animation_events = {}
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
	queries.ensure_resolution(state)
	state.scores = state.scores or {
		turn_bonus = { B = 1, W = 1 },
		territory = { B = 0, W = 0 },
		points = { B = 1, W = 1 },
		plus_mult = { B = 1, W = 1 },
		x_mult = { B = 1, W = 1 },
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
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- Resets point/mult baselines from player bonuses and board `overall_mult`.
--- @param state table
--- @return nil
local function reset_base_scores(state)
	local tn = state.turn_number or 1
	local turn_bonus = 1 + (0.1 * tn)

	state.scores.turn_bonus = { B = turn_bonus, W = turn_bonus }
	state.scores.territory = { B = 0, W = 0 }
	state.scores.plus_mult = state.scores.plus_mult or { B = 1, W = 1 }
	state.scores.x_mult = state.scores.x_mult or { B = 1, W = 1 }
	state.scores.points = state.scores.points or { B = 1, W = 1 }
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

	local turn_bonus_black = state.scores.turn_bonus.B
	local territory_black = state.scores.territory.B
	local points_black = state.scores.points.B
	local plus_mult_black = state.scores.plus_mult.B
	local x_mult_black = state.scores.x_mult.B
	local total_black = calculate_score(turn_bonus_black, territory_black, points_black, plus_mult_black, x_mult_black)

	local turn_bonus_white = state.scores.turn_bonus.W
	local territory_white = state.scores.territory.W
	local points_white = state.scores.points.W
	local plus_mult_white = state.scores.plus_mult.W
	local x_mult_white = state.scores.x_mult.W
	local total_white = calculate_score(turn_bonus_white, territory_white, points_white, plus_mult_white, x_mult_white)

	black.score.turn_bonus = turn_bonus_black
	black.score.territory = territory_black
	black.score.points = points_black
	black.score.plus_mult = plus_mult_black
	black.score.x_mult = x_mult_black
	black.score.total = total_black

	white.score.turn_bonus = turn_bonus_white
	white.score.territory = territory_white
	white.score.points = points_white
	white.score.plus_mult = plus_mult_white
	white.score.x_mult = x_mult_white
	white.score.total = total_white
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

--- Decrements temporary stance durations and removes expired ones.
--- Does not decrement stances created this turn (they expire after being used next turn).
--- @param state table
--- @return nil
local function tick_temporary_stances(state)
	local ObjectInstance = require("single_game.resolver.ObjectInstance")
	local kept = {}
	local active_owner = side_to_owner(state.to_play)
	for _, stance in ipairs(state.temporary_stances or {}) do
		if not stance.created_this_turn and stance.owner == active_owner then
			ObjectInstance.decrement_duration(stance)
		end
		stance.created_this_turn = nil
		if not ObjectInstance.is_expired(stance) then
			kept[#kept + 1] = stance
		end
	end
	state.temporary_stances = kept
end

--- Main entry: runs full PRE/MAIN pipeline including territory begin/finish and clears `round_stone_effects`.
--- @param state table
--- @return nil
function M.resolve(state)
	-- dbg.log_stack("resolve_round", state)
	ensure_state_fields(state)
	-- dbg.log_stack("ensure_state_fields", state)
	sync_opponent_state(state)
	reset_base_scores(state)
	queries.clear_resolution(state)
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
	card_play_memory.flush_just_played_to_history(state)
	state.round_stone_effects = {}
	tick_timed_effects(state)
	tick_temporary_stances(state)
	queries.clear_resolution(state)
end

return M
