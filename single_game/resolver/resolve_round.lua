--- Per-action scoring resolve: macro lifecycle + sub passes (territory → points → mult).
---
--- ``points``, ``plus_mult``, and ``x_mult`` hydrate from ``player.score`` each resolve and persist
--- across turns; only ``territory`` is recomputed from the board. Card effects read
--- ``state.just_played`` for ``playing_cards`` macro only. Stone on-place effects use
--- ``round_stone_effects`` for ``playing_stones`` macro only. Board scan never applies on-place
--- add_points/add_mult (see ``resolve_board_stone``).
--- @module resolver.resolve_round

local config = require("config")
local match_state = require("match_state")
local phases = require("single_game.resolver.phases")
local effect_manager = require("single_game.resolver.effect_manager")
local queries = require("single_game.resolver.state_queries")
local territory = require("single_game.resolver.territory")
local territory_control_rounds = require("single_game.resolver.territory_control_rounds")
local board_cell_timers = require("single_game.resolver.board_cell_timers")
local card_play_memory = require("single_game.resolver.card_play_memory")
local scoring_phases = require("single_game.resolver.scoring_phases")
local anti_capture_immunity = require("single_game.resolver.anti_capture_immunity")
local capture_stone = require("single_game.resolver.capture_stone")
local stone_timers = require("single_game.resolver.stone_timers")
local stone_stored_values = require("single_game.resolver.stone_stored_values")

local M = {}

--- @param state table
--- @return nil
local function ensure_state_fields(state)
	state.round_number = match_state.round_number_from_turn(state.turn_number)
	require("single_game.resolver.blocked_cells").ensure(state)
	state.run_state = state.run_state or {}
	state.run_state.pending_counter_mult_delta = {}
	state.last_opponent_move = state.last_opponent_move or nil
	state.last_opponent_modifiers = state.last_opponent_modifiers or {}
	state.active_effects = state.active_effects or {}
	state.round_stone_effects = state.round_stone_effects or {}
	state.temporary_stances = state.temporary_stances or {}
	state.just_played = state.just_played or {}
	state.played_cards = state.played_cards or {}
	state._pattern_plus_bonus_cells = {}
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
	stone_stored_values.ensure_bag(state)
	territory_control_rounds.ensure_grid(state)
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

--- @param state table
--- @return nil
local function hydrate_score_ledger_from_players(state)
	local black = match_state.player_for_color(state, "black")
	local white = match_state.player_for_color(state, "white")
	state.scores = state.scores or {}
	state.scores.points = {
		B = black.score.points or 1,
		W = white.score.points or 1,
	}
	state.scores.plus_mult = {
		B = black.score.plus_mult or 1,
		W = white.score.plus_mult or 1,
	}
	state.scores.x_mult = {
		B = black.score.x_mult or 1,
		W = white.score.x_mult or 1,
	}
	state.scores.turn_bonus = {
		B = black.score.turn_bonus or 1,
		W = white.score.turn_bonus or 1,
	}
end

--- @param state table
--- @return nil
local function reset_territory_ledger(state)
	state.scores.territory = { B = 0, W = 0 }
end

--- Hydrate persistent factors from ``player.score``, reset territory, optionally refresh active turn bonus.
--- @param state table
--- @param macro string
--- @return nil
local function prepare_score_baselines(state, macro)
	local tn = state.turn_number or 1
	local turn_bonus = 1 + (0.1 * tn)
	if macro == "game_start" then
		state.scores.turn_bonus = { B = turn_bonus, W = turn_bonus }
		state.scores.plus_mult = { B = 1, W = 1 }
		state.scores.x_mult = { B = 1, W = 1 }
		state.scores.points = { B = 1, W = 1 }
		state.scores.territory = { B = 0, W = 0 }
		return
	end
	hydrate_score_ledger_from_players(state)
	reset_territory_ledger(state)
	if macro == "before_turn" then
		local owner = side_to_owner(state.to_play)
		state.scores.turn_bonus[owner] = turn_bonus
	end
end

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

--- Territory sub: distance modifiers → territory-value effects → assign owners and count.
--- @param state table
--- @param macro string
--- @return nil
local function apply_territory_sub(state, macro)
	effect_manager.apply_sub_phase(state, macro, "territory", scoring_phases.TERRITORY_STEP_DISTANCE)
	territory.begin_assignment(state)
	effect_manager.apply_sub_phase(state, macro, "territory", scoring_phases.TERRITORY_STEP_VALUE)
	effect_manager.apply_sub_phase(state, macro, "territory", scoring_phases.TERRITORY_STEP_OVERRIDE)
	territory.finish_assignment(state)
end

--- @param state table
--- @param macro string
--- @return nil
local function run_sub_phases(state, macro)
	for i = 1, #phases.SUB_ORDER do
		local sub = phases.SUB_ORDER[i]
		if sub == "territory" then
			apply_territory_sub(state, macro)
		else
			effect_manager.apply_sub_phase(state, macro, sub, nil)
		end
	end
end

--- @param state table
--- @param opts table|nil ``{ macro = string }``
--- @return nil
function M.resolve(state, opts)
	opts = opts or {}
	local macro = opts.macro or "playing_stones"
	ensure_state_fields(state)
	sync_opponent_state(state)
	prepare_score_baselines(state, macro)
	queries.clear_resolution(state)
	state._resolve_macro = macro
	if macro == "end_of_turn" then
		state._tax_enclosure_paid = {}
	end
	run_sub_phases(state, macro)
	if macro == "end_of_turn" then
		stone_timers.process_expirations(state)
	end
	sync_player_scores(state)
	if macro == "playing_cards" then
		card_play_memory.flush_just_played_to_history(state)
		for _, stance in ipairs(state.temporary_stances or {}) do
			stance.created_this_turn = nil
		end
	elseif macro == "playing_stones" then
		state.round_stone_effects = {}
	end
	if macro == "end_of_turn" then
		if state._decrement_board_cell_timers_on_eot then
			board_cell_timers.decrement(state)
		end
		board_cell_timers.expire(state)
		card_play_memory.flush_just_played_to_history(state)
		local blocked_cells = require("single_game.resolver.blocked_cells")
		blocked_cells.bootstrap_from_board_if_needed(state)
		if not state._blockade_registered_this_action and (state.turn_number or 1) % 2 == 0 then
			blocked_cells.tick(state)
		end
		state._blockade_registered_this_action = nil
		if not state._capture_cooldown_registered_this_action then
			capture_stone.tick_capture_cooldowns(state)
		end
		state._capture_cooldown_registered_this_action = nil
		tick_timed_effects(state)
		anti_capture_immunity.tick(state)
		tick_temporary_stances(state)
		if (state.turn_number or 1) % 2 == 0 then
			territory_control_rounds.tick(state)
		end
	end
	queries.clear_resolution(state)
	state._resolve_macro = nil
end

return M
