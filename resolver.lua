local board = require("board")
local config = require("config")
local content = require("content")
local deck = require("deck")
local energy = require("energy")
local Effects = require("effect_registry")
local match_state = require("match_state")
local messages = require("messages")
local resolve_round = require("single_game.resolver.resolve_round")
local score_display = require("ui.score_display")
local card_play_memory = require("single_game.resolver.card_play_memory")
local pouch = require("pouch")
local rules = require("rules")
local stone_params = require("objects.parameters.stones")

local M = {}

local VALID_CARD_PLAY_MODES = {
	instant = true,
	target_single = true,
	target_multi = true,
}

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

local function owner_for_color(color)
	if color == "white" then
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

--- @param side string
--- @return string
local function owner_for_side(side)
	if side == "white" then
		return config.OWNER_WHITE
	end
	return config.OWNER_BLACK
end

local function normalize_selected_targets(payload, state)
	local function normalize_ref(ref)
		if type(ref) ~= "table" then
			return ref
		end
		if ref.object_type then
			return ref
		end
		if ref.row and ref.col then
			return {
				object_type = "stone",
				row = ref.row,
				col = ref.col,
			}
		end
		return ref
	end
	if payload and type(payload.selected_targets) == "table" then
		local out = {}
		for i = 1, #payload.selected_targets do
			out[#out + 1] = normalize_ref(payload.selected_targets[i])
		end
		return out
	end
	if payload and payload.selected_target then
		return { normalize_ref(payload.selected_target) }
	end
	if state and state.selected_card_target then
		return { normalize_ref(state.selected_card_target) }
	end
	return {}
end

local function target_has_all(tags, required)
	for i = 1, #required do
		if not tags[required[i]] then
			return false
		end
	end
	return true
end

local function target_has_any(tags, required)
	if not required or #required == 0 then
		return true
	end
	for i = 1, #required do
		if tags[required[i]] then
			return true
		end
	end
	return false
end

local function target_has_excluded(tags, excluded)
	if not excluded then
		return false
	end
	for i = 1, #excluded do
		if tags[excluded[i]] then
			return true
		end
	end
	return false
end

local function target_key(ref)
	if ref.object_type == "stone" then
		return table.concat({ "stone", tostring(ref.row), tostring(ref.col) }, ":")
	end
	if ref.object_type == "card" then
		return table.concat({ "card", tostring(ref.owner), tostring(ref.hand_index) }, ":")
	end
	if ref.object_type == "stance" then
		return table.concat({ "stance", tostring(ref.owner), tostring(ref.lane), tostring(ref.slot_index) }, ":")
	end
	return nil
end

local function adjusted_hand_index_after_removals(hand_index, selected_targets, actor)
	local shift = 0
	for i = 1, #selected_targets do
		local ref = selected_targets[i]
		if ref.object_type == "card" and (ref.owner == actor or ref.owner == nil) and type(ref.hand_index) == "number" then
			if ref.hand_index < hand_index then
				shift = shift + 1
			end
		end
	end
	return hand_index - shift
end

--- Source of truth for runtime target tags.
--- @param target_ref table
--- @param actor string|nil
--- @param state table
--- @return string[]
function M.resolve_target_tags(target_ref, actor, state)
	local tags = {}
	if state == nil and type(actor) == "table" then
		state = actor
		actor = nil
	end
	if type(target_ref) ~= "table" then
		return tags
	end
	local acting_side = actor or state.to_play
	local owner = owner_for_color(acting_side)
	if target_ref.object_type == "stone" then
		local row = target_ref.row
		local col = target_ref.col
		local cell = state.board and state.board[row] and state.board[row][col]
		if not cell or board.is_empty(cell) then
			return tags
		end
		local cell_owner = cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
		tags[#tags + 1] = "targetable"
		if cell_owner == owner then
			tags[#tags + 1] = "owner_self"
		else
			tags[#tags + 1] = "owner_opponent"
		end
		local stone_def = content.get_stone(cell.kind)
		if stone_def and stone_def.tags then
			for i = 1, #stone_def.tags do
				tags[#tags + 1] = stone_def.tags[i]
			end
		end
		local stone_solidity = require("objects.stone_solidity")
		local current = cell.solidity or stone_solidity.stone_max_solidity(cell.kind)
		local max_s = stone_solidity.stone_max_solidity(cell.kind)
		if current < max_s then
			tags[#tags + 1] = "damaged"
		end
		if current > 0 then
			tags[#tags + 1] = "upgradable"
		end
		if cell.untargetable == true then
			tags[#tags + 1] = "untargetable"
		end
	elseif target_ref.object_type == "card" then
		local side = target_ref.owner or state.to_play
		local player = match_state.player_for_color(state, side)
		local index = target_ref.hand_index
		local card_id = player and player.cards and player.cards.hand and player.cards.hand.ids and player.cards.hand.ids[index]
		if not card_id then
			return tags
		end
		local card_owner = owner_for_color(side)
		tags[#tags + 1] = "targetable"
		if card_owner == owner then
			tags[#tags + 1] = "owner_self"
		else
			tags[#tags + 1] = "owner_opponent"
		end
		tags[#tags + 1] = "in_hand"
		local card_def = content.get_card(card_id)
		if card_def and card_def.tags then
			for i = 1, #card_def.tags do
				tags[#tags + 1] = card_def.tags[i]
			end
		end
	elseif target_ref.object_type == "stance" then
		local side = target_ref.owner or state.to_play
		local player = match_state.player_for_color(state, side)
		local lane = target_ref.lane
		local index = target_ref.slot_index
		local stance_id = player
			and player.stances
			and player.stances[lane]
			and index
			and player.stances[lane][index]
		if not stance_id then
			return tags
		end
		local stance_owner = owner_for_color(side)
		tags[#tags + 1] = "targetable"
		if stance_owner == owner then
			tags[#tags + 1] = "owner_self"
		else
			tags[#tags + 1] = "owner_opponent"
		end
		local stance_def = content.get_stance(stance_id)
		if stance_def and stance_def.tags then
			for i = 1, #stance_def.tags do
				tags[#tags + 1] = stance_def.tags[i]
			end
		end
	end
	return tags
end

--- @param card_def table
--- @param selected_targets table[]
--- @param state table
--- @param actor string
--- @return table
function M.validate_card_targets(card_def, selected_targets, state, actor)
	local mode = card_def.play_mode or "instant"
	if not VALID_CARD_PLAY_MODES[mode] then
		return { ok = false, error = "Card has invalid play mode" }
	end
	local targets = selected_targets or {}
	if mode == "instant" then
		if #targets > 0 then
			return { ok = false, error = "Card does not accept targets" }
		end
		return { ok = true, error = nil, normalized_targets = {} }
	end
	if mode == "target_single" and #targets ~= 1 then
		return { ok = false, error = "Card requires exactly one target" }
	end
	local min_targets = card_def.min_targets or (mode == "target_single" and 1 or 0)
	local max_targets = card_def.max_targets or (mode == "target_single" and 1 or #targets)
	if #targets < min_targets then
		return { ok = false, error = "Not enough selected targets" }
	end
	if #targets > max_targets then
		return { ok = false, error = "Too many selected targets" }
	end
	local expected_type = card_def.target_object_type
	local normalized = {}
	local seen = {}
	for i = 1, #targets do
		local ref = targets[i]
		if type(ref) ~= "table" then
			return { ok = false, error = "Target ref must be an object" }
		end
		if expected_type and ref.object_type ~= expected_type then
			return { ok = false, error = "Target object type mismatch" }
		end
		local key = target_key(ref)
		if key and seen[key] then
			return { ok = false, error = "Duplicate target selected" }
		end
		if key then
			seen[key] = true
		end
		local tags_arr = M.resolve_target_tags(ref, actor, state)
		local tag_set = {}
		for t = 1, #tags_arr do
			tag_set[tags_arr[t]] = true
		end
		if card_def.target_owner == "self" and not tag_set.owner_self then
			return { ok = false, error = "Target owner mismatch" }
		end
		if card_def.target_owner == "opponent" and not tag_set.owner_opponent then
			return { ok = false, error = "Target owner mismatch" }
		end
		local required_all = card_def.required_tags_all or {}
		if not target_has_all(tag_set, required_all) then
			return { ok = false, error = "Target missing required tags" }
		end
		if not target_has_any(tag_set, card_def.required_tags_any) then
			return { ok = false, error = "Target missing one of required tags" }
		end
		if target_has_excluded(tag_set, card_def.excluded_tags) then
			return { ok = false, error = "Target has excluded tag" }
		end
		normalized[#normalized + 1] = ref
	end
	return { ok = true, error = nil, normalized_targets = normalized }
end

--- @param card_def table
--- @param selected_targets table[]
--- @param candidate table
--- @param state table
--- @param actor string
--- @return table
function M.validate_card_target_candidate(card_def, selected_targets, candidate, state, actor)
	local combined = {}
	local targets = selected_targets or {}
	for i = 1, #targets do
		combined[#combined + 1] = targets[i]
	end
	combined[#combined + 1] = candidate
	local probe_def = {}
	for k, v in pairs(card_def) do
		probe_def[k] = v
	end
	probe_def.min_targets = 0
	return M.validate_card_targets(probe_def, combined, state, actor)
end

--- @param state table
--- @param macro string|nil active scoring macro (``playing_cards``, ``playing_stones``, ``end_of_turn``, …)
--- @return nil
local function recalc_all_scores(state, macro)
	local baseline = score_display.snapshot_scores(state)
	resolve_round.resolve(state, { macro = macro or "playing_stones" })
	score_display.after_resolve(state, baseline, state.ui_animation_events)
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

local territory_control_rounds = require("single_game.resolver.territory_control_rounds")
local territory_stone_payout = require("single_game.resolver.territory_stone_payout")

local IMMEDIATE_PLACEMENT_EFFECT_NAMES = {
	add_points = true,
	add_mult = true,
	mult_control_streak = true,
}

--- @param stone_def table
--- @param state table
--- @param actor string
--- @param row integer
--- @param col integer
--- @return table
local function resolved_stone_effects_from_def(stone_def, state, actor, row, col)
	if type(stone_def.behavior) == "function" then
		return stone_def.behavior(state, actor)
	end
	local out = {}
	if stone_def.effects then
		for i = 1, #stone_def.effects do
			local effect = stone_def.effects[i]
			if effect.effect_name == "mult_control_streak" then
				local delta = territory_control_rounds.placement_plus_mult_delta(
					state,
					row,
					col,
					owner_for_side(actor)
				)
				if delta ~= 0 then
					out[#out + 1] = Effects.stones.resolve({
						effect_name = "add_mult",
						macro = effect.macro or "playing_stones",
						sub = effect.sub or "mult",
						value = delta,
						priority = effect.priority or 10,
					})
				end
			elseif IMMEDIATE_PLACEMENT_EFFECT_NAMES[effect.effect_name] then
				out[#out + 1] = Effects.stones.resolve(effect)
			end
		end
	end
	return out
end

--- @param captures integer
--- @return integer
local function capture_bonus_points_for(captures)
	if captures <= 0 then
		return 0
	end
	return captures * stone_params.capture_bonus_points_per_stone
end

--- @param resolved_effects table
--- @param captures integer
--- @return integer
local function append_capture_bonus_resolved_effects(resolved_effects, captures)
	local bonus = capture_bonus_points_for(captures)
	if bonus <= 0 then
		return 0
	end
	resolved_effects[#resolved_effects + 1] = Effects.stones.resolve({
		effect_name = "add_points",
		macro = "playing_stones",
		sub = "points",
		value = bonus,
		priority = stone_params.default_effect_priority,
	})
	return bonus
end

local function round_effects_from_resolved(resolved_effects)
	local round = {}
	for i = 1, #resolved_effects do
		local r = resolved_effects[i]
		if r.type == "ADD_POINTS" then
			round[i] = {
				effect_name = "add_points",
				macro = "playing_stones",
				sub = "points",
				value = r.value,
				priority = r.priority or 10,
			}
		elseif r.type == "ADD_MULT" then
			round[i] = {
				effect_name = "add_mult",
				macro = "playing_stones",
				sub = "mult",
				value = r.value,
				priority = r.priority or 10,
			}
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
	local drawn_events = {}
	while #actor_state.stones.playable_stones < actor_state.stones.hand_target_size do
		local drawn = pouch.draw(actor_state.stones.pouch)
		if not drawn then
			return drawn_events
		end
		actor_state.stones.playable_stones[#actor_state.stones.playable_stones + 1] = drawn
		drawn_events[#drawn_events + 1] = { stone_id = drawn, target_index = #actor_state.stones.playable_stones }
	end
	return drawn_events
end

local function refresh_selected_stone(actor_state)
	local selected_index = actor_state.stones.selected_stone_index
	if selected_index and actor_state.stones.playable_stones[selected_index] == actor_state.stones.selected_stone then
		return
	end
	actor_state.stones.selected_stone = actor_state.stones.playable_stones[1]
	actor_state.stones.selected_stone_index = (#actor_state.stones.playable_stones > 0) and 1 or nil
end

--- @param state table
--- @param event_queue table
--- @return nil
local function run_event_queue(state, event_queue)
	for i = 1, #event_queue do
		local event = event_queue[i]
		if event.kind == "BOARD_APPLY" then
			if event.row and event.col and event.stone_id then
				territory_stone_payout.record_placement_snapshot(state, event.row, event.col, event.stone_id)
			end
			state.board = event.board
			state.ko_ban = event.ko_ban
			if event.row and event.col then
				territory_control_rounds.clear_cell(state, event.row, event.col)
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
				effects = event.stone_effects or {},
			}
			local def = content.get_stone(event.stone_id)
			if def and event.resolved_stone_effects then
				messages.push(state.messages, stone_placement_message(def, event.resolved_stone_effects))
				push_status_from_messages(state)
			end
		elseif event.kind == "PASS" then
			state.consecutive_passes = state.consecutive_passes + 1
		end
	end
	push_status_from_messages(state)
end

--- @param state table
--- @param actor string
--- @param points_before number
--- @param mult_before number
--- @param capture_bonus_points integer
--- @return nil
local function push_place_stone_score_events(state, actor, points_before, mult_before, capture_bonus_points)
	local actor_state = match_state.player_for_color(state, actor)
	local points_after_stones = actor_state.score.points or 0
	local mult_after_stones = actor_state.score.plus_mult or 1
	local stones_points_delta = points_after_stones - points_before
	local placement_points_delta = stones_points_delta - capture_bonus_points
	if placement_points_delta ~= 0 then
		state.messages.score_events[#state.messages.score_events + 1] = {
			actor = actor,
			kind = "points",
			value = placement_points_delta,
		}
	end
	if capture_bonus_points > 0 then
		state.messages.score_events[#state.messages.score_events + 1] = {
			actor = actor,
			kind = "points",
			value = capture_bonus_points,
			source = "capture",
		}
	end
	local mult_stones_delta = mult_after_stones - mult_before
	if mult_stones_delta ~= 0 then
		state.messages.score_events[#state.messages.score_events + 1] = {
			actor = actor,
			kind = "mult",
			value = mult_stones_delta,
		}
	end
	recalc_all_scores(state, "end_of_turn")
	local points_after = actor_state.score.points or 0
	local mult_after = actor_state.score.plus_mult or 1
	local eot_points_delta = points_after - points_after_stones
	if eot_points_delta ~= 0 then
		state.messages.score_events[#state.messages.score_events + 1] = {
			actor = actor,
			kind = "points",
			value = eot_points_delta,
		}
	end
	local eot_mult_delta = mult_after - mult_after_stones
	if eot_mult_delta ~= 0 then
		state.messages.score_events[#state.messages.score_events + 1] = {
			actor = actor,
			kind = "mult",
			value = eot_mult_delta,
		}
	end
end

--- @param state table
--- @param actor string
--- @return nil
local function on_turn_start(state, actor)
	local actor_state = match_state.player_for_color(state, actor)
	energy.refresh(actor_state.resources)
	state.just_played = {}
	state.selected_card_target = nil
	if not actor_state.stones.selected_stone or not actor_state.stones.selected_stone_index then
		actor_state.stones.selected_stone = actor_state.stones.playable_stones[1]
		actor_state.stones.selected_stone_index = (#actor_state.stones.playable_stones > 0) and 1 or nil
	end
	deck.draw_to_hand_target(actor_state.cards, function(max_value)
		return match_state.rng_next_int(state, max_value)
	end)
	recalc_all_scores(state, "before_turn")
	state.phase = "MAIN_PHASE"
end

local function finish_match_if_needed(state)
	if state.consecutive_passes >= 2 then
		state.ended = true
		state.over = true
		state.phase = "MATCH_END"
		state.end_reason = "two_passes"
		state.to_play = "none"
		local black_total = math.ceil(state.players.black.score.total or 0)
		local white_total = math.ceil(state.players.white.score.total or 0)
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
	local previous_actor = state.to_play
	local previous_actor_state = match_state.player_for_color(state, previous_actor)
	local drawn = refill_playable_stones(previous_actor_state)
	state.stone_draw_events = state.stone_draw_events or {}
	for i = 1, #drawn do
		state.stone_draw_events[#state.stone_draw_events + 1] = {
			actor = previous_actor,
			stone_id = drawn[i].stone_id,
			target_index = drawn[i].target_index,
		}
	end
	state.turn_number = state.turn_number + 1
	state.round_number = match_state.round_number_from_turn(state.turn_number)
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
	elseif action.type == "SELECT_BOARD_TARGET" then
		if state.phase ~= "MAIN_PHASE" then
			return false, "SELECT_BOARD_TARGET allowed only in MAIN_PHASE"
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
	local selected_targets = normalize_selected_targets(action.payload, state)
	for i = 1, #selected_targets do
		local ref = selected_targets[i]
		if ref.object_type == "card" and (ref.owner == action.actor or ref.owner == nil) and ref.hand_index == hand_index then
			return nil, "Played card cannot target itself"
		end
	end
	local target_validation = M.validate_card_targets(card_def, selected_targets, state, action.actor)
	if not target_validation.ok then
		return nil, target_validation.error
	end
	local events = {
		{
			kind = "PLAY_CARD_COMMIT",
			actor = action.actor,
			hand_index = hand_index,
			adjusted_hand_index = adjusted_hand_index_after_removals(hand_index, target_validation.normalized_targets, action.actor),
			energy_cost = card_def.energy_cost,
			card_id = card_id,
			selected_targets = target_validation.normalized_targets,
		},
	}
	return events, nil
end

local function compile_place_stone_events(state, action)
	local actor_state = match_state.player_for_color(state, action.actor)
	local selected_index = actor_state.stones.selected_stone_index
	if not selected_index or not actor_state.stones.playable_stones[selected_index] then
		return nil, "No stone selected"
	end
	local stone_id = actor_state.stones.playable_stones[selected_index]
	if not stone_id then
		return nil, "No stone selected"
	end
	if not contains_stone_id(actor_state.stones.playable_stones, stone_id) then
		return nil, "Selected stone is not available"
	end
	local instance_by_slot = actor_state.stones.instance_by_slot
	local instance = instance_by_slot and instance_by_slot[selected_index] or nil
	local stone_ref = instance or stone_id
	local stone_def = content.resolve_stone(stone_ref)
	if not stone_def then
		return nil, "Unknown selected stone"
	end
	local placement_level = instance and instance.level or nil
	local row = action.payload and action.payload.row or -1
	local col = action.payload and action.payload.col or -1
	local ok, new_board, new_ko, captures, illegal_reason = rules.try_play(
		state.board,
		row,
		col,
		color_to_stone(action.actor),
		state.ko_ban,
		stone_id,
		placement_level
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
	local resolved_effects = resolved_stone_effects_from_def(stone_def, state, action.actor, row, col)
	local capture_bonus_points = append_capture_bonus_resolved_effects(resolved_effects, captures)
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
			capture_bonus_points = capture_bonus_points,
			stone_id = stone_id,
			stone_index = selected_index,
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
	local stone_index = action.payload and action.payload.stone_index or nil
	if not stone_id then
		return nil, "Missing stone selection"
	end
	if stone_index and actor_state.stones.playable_stones[stone_index] == stone_id then
		return {
			{
				kind = "SELECT_STONE_COMMIT",
				actor = action.actor,
				stone_id = stone_id,
				stone_index = stone_index,
			},
		}, nil
	end
	if contains_stone_id(actor_state.stones.playable_stones, stone_id) then
		local found_index = nil
		for i = 1, #actor_state.stones.playable_stones do
			if actor_state.stones.playable_stones[i] == stone_id then
				found_index = i
				break
			end
		end
		return {
			{
				kind = "SELECT_STONE_COMMIT",
				actor = action.actor,
				stone_id = stone_id,
				stone_index = found_index,
			},
		}, nil
	end
	return nil, "Stone is not selectable"
end

local function compile_select_board_target_events(state, action)
	local row = action.payload and action.payload.row or nil
	local col = action.payload and action.payload.col or nil
	if not row or not col then
		return nil, "Missing board target coordinates"
	end
	if not state.board[row] then
		return nil, "Target row out of bounds"
	end
	local cell = state.board[row][col]
	if board.is_empty(cell) then
		return nil, "Target must be a placed stone"
	end
	return {
		{
			kind = "SELECT_BOARD_TARGET_COMMIT",
			actor = action.actor,
			row = row,
			col = col,
			stone_id = cell.kind,
			stone_color = cell.color,
		},
	}, nil
end

local function append_reactive_pose_events(state, actor, events)
	return state, actor, events
end

local function remove_hand_card_at_index(cards_state, hand_index)
	if hand_index < 1 or hand_index > #cards_state.hand.ids then
		return false
	end
	local card_id = table.remove(cards_state.hand.ids, hand_index)
	cards_state.discard.ids[#cards_state.discard.ids + 1] = card_id
	return true
end

local function discard_selected_card_targets(state, selected_targets)
	local card_refs = {}
	for i = 1, #selected_targets do
		if selected_targets[i].object_type == "card" then
			card_refs[#card_refs + 1] = selected_targets[i]
		end
	end
	table.sort(card_refs, function(a, b)
		local ao = tostring(a.owner or "")
		local bo = tostring(b.owner or "")
		if ao ~= bo then
			return ao < bo
		end
		return (a.hand_index or 0) > (b.hand_index or 0)
	end)
	for i = 1, #card_refs do
		local ref = card_refs[i]
		local side = ref.owner or state.to_play
		local player = match_state.player_for_color(state, side)
		if not player or not player.cards then
			return false
		end
		if not remove_hand_card_at_index(player.cards, ref.hand_index) then
			return false
		end
	end
	return true
end

local function apply_non_effect_event(state, event)
	if event.kind == "PLAY_CARD_COMMIT" then
		local actor_state = match_state.player_for_color(state, event.actor)
		if not discard_selected_card_targets(state, event.selected_targets or {}) then
			return false, "Failed to discard selected targets"
		end
		local spent = energy.spend(actor_state.resources, event.energy_cost)
		if not spent then
			return false, "Insufficient energy"
		end
		local played = deck.play_from_hand(actor_state.cards, event.adjusted_hand_index or event.hand_index)
		if not played then
			return false, "Invalid hand index"
		end
		card_play_memory.record_just_played_card(state, {
			type = event.card_id,
			owner = owner_for_side(event.actor),
			selected_target = event.selected_targets and event.selected_targets[1] or nil,
			selected_targets = event.selected_targets,
		})
		state.last_opponent_modifiers = state.last_opponent_modifiers or {}
		state.last_opponent_modifiers[#state.last_opponent_modifiers + 1] = {
			type = event.card_id,
			actor = event.actor,
		}
		recalc_all_scores(state, "playing_cards")
		state.selected_card_target = nil
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
		actor_state.stones.selected_stone_index = event.stone_index
		local stone = content.get_stone(event.stone_id)
		messages.push(state.messages, "Selected stone: " .. (stone and stone.name or event.stone_id))
		push_status_from_messages(state)
		return true, nil
	end
	if event.kind == "SELECT_BOARD_TARGET_COMMIT" then
		state.selected_card_target = {
			row = event.row,
			col = event.col,
			stone_id = event.stone_id,
			stone_color = event.stone_color,
		}
		local stone = content.get_stone(event.stone_id)
		messages.push(state.messages, "Selected board target: " .. (stone and stone.name or event.stone_id))
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
		actor_mult_before = actor_state.score.plus_mult or 1
	end
	if action.type == "PLAY_CARD" then
		event_queue, compile_error = compile_play_card_events(state, action)
	elseif action.type == "PLACE_STONE" then
		event_queue, compile_error = compile_place_stone_events(state, action)
	elseif action.type == "SELECT_STONE" then
		event_queue, compile_error = compile_select_stone_events(state, action)
	elseif action.type == "SELECT_BOARD_TARGET" then
		event_queue, compile_error = compile_select_board_target_events(state, action)
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

	if action.type == "PLAY_CARD" or action.type == "SELECT_STONE" or action.type == "SELECT_BOARD_TARGET" then
		return {
			ok = true,
			error = nil,
			consumed_phase = "MAIN_PHASE",
			emitted_events = #event_queue,
		}
	end

	state.phase = "RESOLVE_PHASE"
	local capture_bonus_points = 0
	if action.type == "PLACE_STONE" then
		for i = 1, #event_queue do
			local event = event_queue[i]
			if event.kind == "BOARD_APPLY" then
				capture_bonus_points = event.capture_bonus_points or 0
				break
			end
		end
	end
	if action.type == "PASS_TURN" then
		recalc_all_scores(state, "end_of_turn")
	elseif action.type == "PLACE_STONE" then
		recalc_all_scores(state, "playing_stones")
	end
	if action.type == "PLACE_STONE" then
		push_place_stone_score_events(state, action.actor, actor_points_before, actor_mult_before, capture_bonus_points)
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
	local ev = state.ui_animation_events
	if type(ev) == "table" and #ev > 0 then
		state.pending_turn_after_ui = true
	else
		begin_next_turn(state)
	end
	return {
		ok = true,
		error = nil,
		consumed_phase = "PLACE_PHASE",
		emitted_events = #event_queue,
	}
end

--- When ``submit_action`` deferred ``begin_next_turn`` because UI intents were queued, runs it after jobs finish.
--- @param state table
--- @return nil
function M.flush_pending_turn_if_ready(state)
	if not state or state.pending_turn_after_ui ~= true then
		return
	end
	local ui_animations = require("ui.animations")
	if ui_animations.has_active_jobs() then
		return
	end
	state.pending_turn_after_ui = false
	score_display.end_rollout(state)
	begin_next_turn(state)
end

return M
