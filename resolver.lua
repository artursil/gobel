local board = require("board")
local config = require("config")
local content = require("content")
local deck = require("deck")
local energy = require("energy")
local Effects = require("effect_registry")
local match_state = require("match_state")
local messages = require("messages")
local resolve_round = require("resolver.resolve_round")
local pouch = require("pouch")
local rules = require("rules")

local M = {}

--- @param color string
--- @return integer
local function color_to_stone(color)
	if color == "black" then
		return config.STONE_BLACK
	end
	return config.STONE_WHITE
end

--- @param color string
--- @return string
local function opponent_color(color)
	if color == "black" then
		return "white"
	end
	return "black"
end

--- @param side string
--- @return string
local function owner_for_side(side)
	if side == "white" then
		return "B"
	end
	return "A"
end

--- @param state table
--- @return nil
local function recalc_all_scores(state)
	resolve_round.resolve(state)
end

local function push_status_from_messages(state)
	local recent = state.messages.recent
	local latest = recent[#recent]
	if latest then
		state.status = latest
	end
end

local function card_play_message(card_def)
	if not card_def or not card_def.effects then
		return "Card played"
	end
	local label = card_def.display_name or card_def.name or "Card"
	local parts = {}
	for i = 1, #card_def.effects do
		local e = card_def.effects[i]
		if e.effect_name == "add_points" then
			parts[#parts + 1] = string.format("+%d points", e.value)
		elseif e.effect_name == "add_mult" then
			parts[#parts + 1] = string.format("+%d mult", e.value)
		end
	end
	return label .. ": " .. table.concat(parts, ", ")
end

local function stone_placement_message(stone_def, resolved_effects)
	if not stone_def or not resolved_effects or #resolved_effects == 0 then
		return (stone_def and stone_def.name or "Stone") .. " placed"
	end
	local name = stone_def.name
	local r = resolved_effects[1]
	if r.type == "ADD_POINTS" then
		return string.format("%s placement: +%d points", name, r.value)
	end
	if r.type == "ADD_MULT" then
		return string.format("%s placement: +%d mult", name, r.value)
	end
	return name .. " placed"
end

local function resolved_stone_effects_from_def(stone_def, state, actor)
	if type(stone_def.behavior) == "function" then
		return stone_def.behavior(state, actor)
	end
	local out = {}
	if stone_def.effects then
		for i = 1, #stone_def.effects do
			local effect = stone_def.effects[i]
			if effect.phase == "points" or effect.phase == "mult" then
				out[i] = Effects.stones.resolve(effect)
			end
		end
	end
	return out
end

local function round_effects_from_resolved(resolved_effects)
	local round = {}
	for i = 1, #resolved_effects do
		local r = resolved_effects[i]
		if r.type == "ADD_POINTS" then
			round[i] = { effect_name = "add_points", phase = r.phase or "points", value = r.value, priority = r.priority or 10 }
		elseif r.type == "ADD_MULT" then
			round[i] = { effect_name = "add_mult", phase = r.phase or "mult", value = r.value, priority = r.priority or 10 }
		end
	end
	return round
end

local function contains_stone_id(ids, stone_id)
	for i = 1, #ids do
		if ids[i] == stone_id then
			return true
		end
	end
	return false
end

local function remove_first_stone_id(ids, stone_id)
	for i = 1, #ids do
		if ids[i] == stone_id then
			table.remove(ids, i)
			return true
		end
	end
	return false
end

local function refill_playable_stones(actor_state)
	while #actor_state.stones.playable_stones < actor_state.stones.hand_target_size do
		local drawn = pouch.draw(actor_state.stones.pouch)
		if not drawn then
			return
		end
		actor_state.stones.playable_stones[#actor_state.stones.playable_stones + 1] = drawn
	end
end

local function refresh_selected_stone(actor_state)
	if contains_stone_id(actor_state.stones.playable_stones, actor_state.stones.selected_stone) then
		return
	end
	actor_state.stones.selected_stone = actor_state.stones.playable_stones[1]
end

--- @param state table
--- @param event_queue table
--- @return nil
local function run_event_queue(state, event_queue)
	for i = 1, #event_queue do
		local event = event_queue[i]
		if event.kind == "BOARD_APPLY" then
			state.board = event.board
			state.ko_ban = event.ko_ban
			state.last_played_stone = event.stone_id
			state.last_opponent_move = { stone_id = event.stone_id, row = event.row, col = event.col, actor = event.actor }
			local actor_state = match_state.player_for_color(state, event.actor)
			actor_state.prisoners = actor_state.prisoners + event.captures
			if remove_first_stone_id(actor_state.stones.playable_stones, event.stone_id) then
				refill_playable_stones(actor_state)
			end
			refresh_selected_stone(actor_state)
			state.consecutive_passes = 0
			state.round_stone_effects = state.round_stone_effects or {}
			state.round_stone_effects[#state.round_stone_effects + 1] = {
				owner = owner_for_side(event.actor),
				stone_type = event.stone_id,
				effects = event.stone_effects or {},
			}
			recalc_all_scores(state)
			local def = content.get_stone(event.stone_id)
			if def and event.resolved_stone_effects then
				messages.push(state.messages, stone_placement_message(def, event.resolved_stone_effects))
				push_status_from_messages(state)
			end
		elseif event.kind == "PASS" then
			state.consecutive_passes = state.consecutive_passes + 1
			recalc_all_scores(state)
		end
	end
	push_status_from_messages(state)
end

local function push_score_delta_events(state, actor, points_before, mult_before)
	local actor_state = match_state.player_for_color(state, actor)
	local points_after = actor_state.score.points or 0
	local mult_after = actor_state.score.mult or 0
	local points_delta = points_after - points_before
	local mult_delta = mult_after - mult_before
	if points_delta ~= 0 then
		state.messages.score_events[#state.messages.score_events + 1] = {
			actor = actor,
			kind = "points",
			value = points_delta,
		}
	end
	if mult_delta ~= 0 then
		state.messages.score_events[#state.messages.score_events + 1] = {
			actor = actor,
			kind = "mult",
			value = mult_delta,
		}
	end
end

--- @param state table
--- @param actor string
--- @return nil
local function on_turn_start(state, actor)
	local actor_state = match_state.player_for_color(state, actor)
	energy.refresh(actor_state.resources)
	state.modifiers = {}
	if not actor_state.stones.selected_stone then
		actor_state.stones.selected_stone = actor_state.stones.playable_stones[1]
	end
	deck.draw_to_hand_target(actor_state.cards, function(max_value)
		return match_state.rng_next_int(state, max_value)
	end)
	state.phase = "MAIN_PHASE"
end

local function finish_match_if_needed(state)
	if state.consecutive_passes >= 2 then
		state.ended = true
		state.over = true
		state.phase = "MATCH_END"
		state.end_reason = "two_passes"
		state.to_play = "none"
		local black_total = state.players.black.score.total
		local white_total = state.players.white.score.total
		if black_total > white_total then
			state.winner = "black"
		elseif white_total > black_total then
			state.winner = "white"
		else
			state.winner = "draw"
		end
		local winner_name = state.winner == "draw" and "Draw" or (state.winner == "black" and "Black" or "White")
		messages.push(
			state.messages,
			string.format("Game over — Black: %d  White: %d (%s).", black_total, white_total, winner_name)
		)
		push_status_from_messages(state)
		return true
	end
	return false
end

local function begin_next_turn(state)
	state.turn_number = state.turn_number + 1
	state.to_play = opponent_color(state.to_play)
	state.phase = "TURN_START"
	on_turn_start(state, state.to_play)
end

local function validate_actor_phase(state, action)
	if state.ended or state.over then
		return false, "Match already ended"
	end
	if action.actor ~= state.to_play then
		return false, "Actor does not match active side"
	end
	if action.type == "PLAY_CARD" then
		if state.phase ~= "MAIN_PHASE" then
			return false, "PLAY_CARD allowed only in MAIN_PHASE"
		end
	elseif action.type == "SELECT_STONE" then
		if state.phase ~= "MAIN_PHASE" and state.phase ~= "PLACE_PHASE" then
			return false, "SELECT_STONE allowed only in MAIN_PHASE or PLACE_PHASE"
		end
	elseif action.type == "PLACE_STONE" or action.type == "PASS_TURN" then
		if state.phase ~= "PLACE_PHASE" then
			return false, action.type .. " allowed only in PLACE_PHASE"
		end
	else
		return false, "Unsupported action type"
	end
	return true, nil
end

local function compile_play_card_events(state, action)
	local actor_state = match_state.player_for_color(state, action.actor)
	local hand_index = action.payload and action.payload.hand_index or -1
	if not deck.can_play_from_hand(actor_state.cards, hand_index) then
		return nil, "Invalid hand index"
	end
	local card_id = actor_state.cards.hand.ids[hand_index]
	local card_def = content.get_card(card_id)
	if not card_def then
		return nil, "Unknown card id"
	end
	if not energy.can_spend(actor_state.resources, card_def.energy_cost) then
		return nil, "Insufficient energy"
	end
	local events = {
		{
			kind = "PLAY_CARD_COMMIT",
			actor = action.actor,
			hand_index = hand_index,
			energy_cost = card_def.energy_cost,
			card_id = card_id,
		},
	}
	return events, nil
end

local function compile_place_stone_events(state, action)
	local actor_state = match_state.player_for_color(state, action.actor)
	local stone_id = actor_state.stones.selected_stone
	if not stone_id then
		return nil, "No stone selected"
	end
	if not contains_stone_id(actor_state.stones.playable_stones, stone_id) then
		return nil, "Selected stone is not available"
	end
	local stone_def = content.get_stone(stone_id)
	if not stone_def then
		return nil, "Unknown selected stone"
	end
	local row = action.payload and action.payload.row or -1
	local col = action.payload and action.payload.col or -1
	local ok, new_board, new_ko, captures, illegal_reason = rules.try_play(
		state.board,
		row,
		col,
		color_to_stone(action.actor),
		state.ko_ban,
		stone_id
	)
	if not ok then
		if illegal_reason == "occupied" then
			return nil, "Illegal move: intersection is occupied"
		end
		if illegal_reason == "ko" then
			return nil, "Illegal move: ko rule forbids this point this turn"
		end
		if illegal_reason == "suicide" then
			return nil, "Illegal move: move has no liberties (suicide)"
		end
		if illegal_reason == "out_of_bounds" then
			return nil, "Illegal move: out of bounds"
		end
		return nil, "Illegal move: rule violation"
	end
	local resolved_effects = resolved_stone_effects_from_def(stone_def, state, action.actor)
	if type(resolved_effects) ~= "table" or #resolved_effects == 0 then
		return nil, "Stone behavior produced invalid effect"
	end
	for i = 1, #resolved_effects do
		local resolved = resolved_effects[i]
		if not resolved or type(resolved) ~= "table" or (resolved.type ~= "ADD_POINTS" and resolved.type ~= "ADD_MULT") or type(resolved.value) ~= "number" then
			return nil, "Stone behavior produced invalid effect"
		end
	end
	local placement_round = round_effects_from_resolved(resolved_effects)
	local events = {
		{
			kind = "BOARD_APPLY",
			actor = action.actor,
			board = new_board,
			ko_ban = new_ko,
			captures = captures,
			stone_id = stone_id,
			row = row,
			col = col,
			stone_effects = placement_round,
			resolved_stone_effects = resolved_effects,
		},
	}
	return events, nil
end

local function compile_pass_events()
	return { { kind = "PASS" } }, nil
end

local function compile_select_stone_events(state, action)
	local actor_state = match_state.player_for_color(state, action.actor)
	local stone_id = action.payload and action.payload.stone_id or nil
	if not stone_id then
		return nil, "Missing stone selection"
	end
	if contains_stone_id(actor_state.stones.playable_stones, stone_id) then
		return {
			{
				kind = "SELECT_STONE_COMMIT",
				actor = action.actor,
				stone_id = stone_id,
			},
		}, nil
	end
	return nil, "Stone is not selectable"
end

local function append_reactive_pose_events(state, actor, events)
	return state, actor, events
end

local function apply_non_effect_event(state, event)
	if event.kind == "PLAY_CARD_COMMIT" then
		local actor_state = match_state.player_for_color(state, event.actor)
		local spent = energy.spend(actor_state.resources, event.energy_cost)
		if not spent then
			return false, "Insufficient energy"
		end
		local played = deck.play_from_hand(actor_state.cards, event.hand_index)
		if not played then
			return false, "Invalid hand index"
		end
		state.modifiers[#state.modifiers + 1] = {
			type = event.card_id,
			owner = owner_for_side(event.actor),
		}
		state.last_opponent_modifiers = state.last_opponent_modifiers or {}
		state.last_opponent_modifiers[#state.last_opponent_modifiers + 1] = {
			type = event.card_id,
			actor = event.actor,
		}
		recalc_all_scores(state)
		local cdef = content.get_card(event.card_id)
		if cdef then
			messages.push(state.messages, card_play_message(cdef))
			push_status_from_messages(state)
		end
		return true, nil
	end
	if event.kind == "SELECT_STONE_COMMIT" then
		local actor_state = match_state.player_for_color(state, event.actor)
		actor_state.stones.selected_stone = event.stone_id
		local stone = content.get_stone(event.stone_id)
		messages.push(state.messages, "Selected stone: " .. (stone and stone.name or event.stone_id))
		push_status_from_messages(state)
		return true, nil
	end
	return true, nil
end

function M.finish_main_phase(state, actor)
	if state.ended or state.over then
		return { ok = false, error = "Match already ended", consumed_phase = state.phase, emitted_events = 0 }
	end
	if actor ~= state.to_play then
		return { ok = false, error = "Actor does not match active side", consumed_phase = state.phase, emitted_events = 0 }
	end
	if state.phase ~= "MAIN_PHASE" then
		return { ok = false, error = "Not in MAIN_PHASE", consumed_phase = state.phase, emitted_events = 0 }
	end
	state.phase = "PLACE_PHASE"
	return { ok = true, error = nil, consumed_phase = "MAIN_PHASE", emitted_events = 0 }
end

function M.begin_turn(state, actor)
	if actor ~= state.to_play then
		return { ok = false, error = "Actor does not match active side", consumed_phase = state.phase, emitted_events = 0 }
	end
	if state.phase ~= "TURN_START" then
		return { ok = false, error = "Not in TURN_START", consumed_phase = state.phase, emitted_events = 0 }
	end
	messages.push(state.messages, "Turn start: " .. actor)
	push_status_from_messages(state)
	state.phase = "DRAW_PHASE"
	on_turn_start(state, actor)
	return { ok = true, error = nil, consumed_phase = "TURN_START", emitted_events = 0 }
end

function M.submit_action(state, action)
	local valid, validation_error = validate_actor_phase(state, action)
	if not valid then
		return {
			ok = false,
			error = validation_error,
			consumed_phase = state.phase,
			emitted_events = 0,
		}
	end
	local event_queue
	local compile_error
	local actor_points_before = nil
	local actor_mult_before = nil
	if action.type == "PLACE_STONE" then
		local actor_state = match_state.player_for_color(state, action.actor)
		actor_points_before = actor_state.score.points or 0
		actor_mult_before = actor_state.score.mult or 0
	end
	if action.type == "PLAY_CARD" then
		event_queue, compile_error = compile_play_card_events(state, action)
	elseif action.type == "PLACE_STONE" then
		event_queue, compile_error = compile_place_stone_events(state, action)
	elseif action.type == "SELECT_STONE" then
		event_queue, compile_error = compile_select_stone_events(state, action)
	else
		event_queue, compile_error = compile_pass_events()
	end

	if compile_error then
		return {
			ok = false,
			error = compile_error,
			consumed_phase = state.phase,
			emitted_events = 0,
		}
	end
	append_reactive_pose_events(state, action.actor, event_queue)

	for i = 1, #event_queue do
		local event = event_queue[i]
		if event.kind == "BOARD_APPLY" or event.kind == "PASS" then
			run_event_queue(state, { event })
		else
			local ok, error_text = apply_non_effect_event(state, event)
			if not ok then
				return {
					ok = false,
					error = error_text,
					consumed_phase = state.phase,
					emitted_events = i - 1,
				}
			end
		end
	end

	if action.type == "PLAY_CARD" or action.type == "SELECT_STONE" then
		return {
			ok = true,
			error = nil,
			consumed_phase = "MAIN_PHASE",
			emitted_events = #event_queue,
		}
	end

	state.phase = "RESOLVE_PHASE"
	recalc_all_scores(state)
	if action.type == "PLACE_STONE" then
		push_score_delta_events(state, action.actor, actor_points_before, actor_mult_before)
	end
	state.phase = "TURN_END"
	if finish_match_if_needed(state) then
		return {
			ok = true,
			error = nil,
			consumed_phase = "PLACE_PHASE",
			emitted_events = #event_queue,
		}
	end
	begin_next_turn(state)
	return {
		ok = true,
		error = nil,
		consumed_phase = "PLACE_PHASE",
		emitted_events = #event_queue,
	}
end

return M
