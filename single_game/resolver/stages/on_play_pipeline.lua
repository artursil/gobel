--- On-play pipeline: commit → (scoring via caller) → animations → drain removals → legality.
--- @module single_game.resolver.stages.on_play_pipeline

local board = require("board")
local config = require("config")
local content = require("content")
local match_state = require("match_state")
local messages = require("messages")
local stone_params = require("objects.parameters.stones")
local Effects = require("effect_registry")
local dispatch_removed = require("single_game.resolver.stages.dispatch_removed")
local remove_stones = require("single_game.resolver.stages.remove_stones")
local legality_of_moves = require("single_game.resolver.stages.legality_of_moves")
local stone_timers = require("single_game.resolver.stone_timers")
local territory_control_rounds = require("single_game.resolver.helpers.territory_control_rounds")
local territory_resolver = require("single_game.resolver.territory")
local effects_helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")

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
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- Applies timer/setup hooks when a deferred-turn stone is placed without a full scoring pass.
--- @param state table
--- @param stone_effects table
--- @param resolved_effects table|nil
--- @param row integer
--- @param col integer
--- @param owner string
--- @return nil
local function apply_continuation_placement_setup(state, stone_effects, resolved_effects, row, col, owner)
	for i = 1, #(stone_effects or {}) do
		local effect_def = stone_effects[i]
		if effect_def.effect_name == "delay_reward_setup" then
			local resolved = Effects.stones.resolve(effect_def)
			if resolved and resolved.apply then
				resolved.apply(state, owner, { row = row, col = col })
			end
		elseif effect_def.effect_name == "self_destruct_setup" then
			local resolved = Effects.stones.resolve(effect_def)
			if resolved and resolved.apply then
				resolved.apply(state, owner, { row = row, col = col })
			end
		end
	end
end

--- @param ids string[]
--- @param stone_id string
--- @return boolean
local function remove_first_stone_id(ids, stone_id)
	for i = 1, #ids do
		if ids[i] == stone_id then
			table.remove(ids, i)
			return true
		end
	end
	return false
end

--- @param actor_state table
--- @return nil
local function refresh_selected_stone(actor_state)
	local selected_index = actor_state.stones.selected_stone_index
	if selected_index and actor_state.stones.playable_stones[selected_index] == actor_state.stones.selected_stone then
		return
	end
	actor_state.stones.selected_stone = actor_state.stones.playable_stones[1]
	actor_state.stones.selected_stone_index = (#actor_state.stones.playable_stones > 0) and 1 or nil
end

--- @param stone_def table|nil
--- @param resolved_effects table|nil
--- @return string
local function stone_placement_message(stone_def, resolved_effects)
	if not stone_def or not resolved_effects or #resolved_effects == 0 then
		return (stone_def and stone_def.name or "Stone") .. " placed"
	end
	local name = stone_def.name
	local r = resolved_effects[1]
	if r.effect_name == "add_points" or r.effect_name == "kamikaze_sacrifice" or r.effect_name == "self_destruct_setup" then
		local points = r.value or r.immediate_points
		return string.format("%s placement: +%d points", name, points)
	end
	if r.effect_name == "add_mult" then
		return string.format("%s placement: +%d mult", name, r.value)
	end
	return name .. " placed"
end

--- Drain ``pending_stone_removals`` after on-play scoring (post-animation beat).
--- @param ctx table ``{ state, actor, player_chain_color? }``
--- @return integer supplemental_captures
--- @return boolean kamikaze_sacrifice_applies
function M.remove_stones(ctx)
	return remove_stones.run(ctx)
end

--- Placement-beat animations (stub until animation hooks register jobs).
--- @param state table
--- @return nil
function M.run_placement_animations(_state)
end

--- After scoring: animate → drain pending removals → prisoner side effects.
--- @param state table
--- @return nil
function M.run_removal_beat(state)
	local move = state.last_opponent_move
	if not move or not move.row or not move.col or not move.actor then
		return
	end
	M.run_placement_animations(state)
	local remove_ctx = {
		state = state,
		actor = move.actor,
		player_chain_color = color_to_stone(move.actor),
	}
	local _, kamikaze_sacrifice_applies = M.remove_stones(remove_ctx)
	if kamikaze_sacrifice_applies and stone_params.kamikaze_self_removal_counts_as_prisoner then
		local opp_state = match_state.player_for_color(state, opponent_color(move.actor))
		opp_state.prisoners = (opp_state.prisoners or 0) + 1
	end
end

--- After card scoring: animate then drain pending removals for card effects.
--- @param state table
--- @param actor string
--- @return nil
function M.run_card_removal_beat(state, actor)
	if not actor then
		return
	end
	M.run_placement_animations(state)
	M.remove_stones({
		state = state,
		actor = actor,
		player_chain_color = color_to_stone(actor),
	})
end

--- Step 6: refresh cached legal moves.
--- @param state table
--- @return nil
function M.recalculate_legal_moves(state)
	legality_of_moves.run(state)
end

--- Step 1: commit board and update placement state (regular Go captures at commit).
--- Scoring, removal beat, and legality are orchestrated by the resolver after this call.
--- @param state table
--- @param event table BOARD_APPLY event
--- @return nil
function M.run(state, event)
	pending_removals.ensure_queue(state)
	local old_board = state.board
	dispatch_removed.preserve_cell_metadata(old_board, event.board)
	if event.row and event.col and event.stone_id then
		territory_resolver.capture_placement_snapshot_if_needed(state, event.row, event.col, event.stone_id)
	end
	state.board = event.board
	local stone_def = event.stone_id and content.get_stone(event.stone_id) or nil
	if stone_def and effects_helpers.stone_def_has_capture_zero_liberty_effect(stone_def) then
		effects_helpers.apply_capture_cooldowns_for_removals(
			state,
			old_board,
			event.board,
			event.actor,
			color_to_stone(event.actor)
		)
	end
	dispatch_removed.run(state, old_board, state.board, { capturer = event.actor })
	stone_timers.clear_removed_stones(state, old_board, state.board)
	local stone_effects = event.stone_effects or {}
	if state._continuation_deferred_placement then
		apply_continuation_placement_setup(
			state,
			stone_effects,
			event.resolved_stone_effects,
			event.row,
			event.col,
			owner_for_side(event.actor)
		)
	end
	state.ko_ban = event.ko_ban
	if event.row and event.col then
		territory_control_rounds.record_placement_streak_snapshot(state, event.row, event.col)
		territory_control_rounds.clear_cell(state, event.row, event.col)
		dispatch_removed.mark_placed_via_play(state, event.row, event.col)
	end
	state.last_played_stone = event.stone_id
	state.last_opponent_move = { stone_id = event.stone_id, row = event.row, col = event.col, actor = event.actor }
	local actor_state = match_state.player_for_color(state, event.actor)
	actor_state.prisoners = actor_state.prisoners + event.captures
	if event.stone_index and actor_state.stones.playable_stones[event.stone_index] == event.stone_id then
		table.remove(actor_state.stones.playable_stones, event.stone_index)
	elseif remove_first_stone_id(actor_state.stones.playable_stones, event.stone_id) then
	end
	refresh_selected_stone(actor_state)
	state.consecutive_passes = 0
	state.round_stone_effects = state.round_stone_effects or {}
	state.round_stone_effects[#state.round_stone_effects + 1] = {
		owner = owner_for_side(event.actor),
		stone_type = event.stone_id,
		row = event.row,
		col = event.col,
		effects = stone_effects,
	}
	local def = content.get_stone(event.stone_id)
	if def and event.resolved_stone_effects then
		messages.push(state.messages, stone_placement_message(def, event.resolved_stone_effects))
	end
end

return M
