--- Unified effect operation registry.
--- Consolidated from individual stone/card/stance modules for PR 3 unification.
--- Single dispatcher for all effect types across the game.
--- @module objects.effects

local config = require("config")
local board = require("board")
local queries = require("single_game.resolver.state_queries")
local helpers = require("objects.effects_helpers")
local animations = require("objects.animations")
local shape_patterns = require("game.patterns.shape_patterns")
local shared_stones_effects = require("objects.definitions.shared_stones_effects")
local stone_params = require("objects.parameters.stones")
local stance_params = require("objects.parameters.stances")
local card_params = require("objects.parameters.cards")

local M = {}

--- Add points effect builder.
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.add_points(effect)
	local sub = effect.sub or effect.phase or "points"
	return {
		type = "ADD_POINTS",
		phase = sub,
		macro = effect.macro,
		sub = sub,
		value = effect.value,
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner)
			state.scores.points[owner] = state.scores.points[owner] + effect.value
		end,
	}
end

--- Add multiplier effect builder.
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.add_mult(effect)
	local sub = effect.sub or effect.phase or "mult"
	return {
		type = "ADD_MULT",
		phase = sub,
		macro = effect.macro,
		sub = sub,
		value = effect.value,
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner)
			state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + effect.value
		end,
	}
end

--- Distance bonus effect builder (no apply; used for state precomputation).
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply?}
function M.distance_bonus(effect)
	return {
		type = "DISTANCE_BONUS",
		phase = "territory",
		macro = effect.macro or "playing_stones",
		sub = "territory",
		territory_step = effect.territory_step or "distance",
		value = effect.value,
		priority = effect.priority or 10,
		conditions = effect.conditions,
	}
end

--- Count and multiply x_mult effect builder.
--- Counts cards with a specific tag in hand and multiplies x_mult by (1 + value) for each card.
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.count_and_multiply_x_mult(effect)
	return {
		type = "COUNT_AND_MULTIPLY_X_MULT",
		phase = effect.phase or "mult",
		value = effect.value,
		priority = effect.priority or 15,
		conditions = effect.conditions,
		apply = function(state, owner)
			local match_state = require("match_state")
			local player_state = match_state.player_for_color(state, owner == config.OWNER_BLACK and "black" or "white")
			if not player_state then
				return
			end

			local hand_ids = player_state.cards.hand and player_state.cards.hand.ids
			if not hand_ids then
				return
			end

			local content = require("content")
			local steel_card_count = 0
			local steel_hand_indices = {}
			for hand_index, card_id in ipairs(hand_ids) do
				if card_id then
					local card_def = content.get_card(card_id)
					if card_def and card_def.tags then
						for _, tag in ipairs(card_def.tags) do
							if tag == "steel" then
								steel_card_count = steel_card_count + 1
								steel_hand_indices[#steel_hand_indices + 1] = hand_index
								break
							end
						end
					end
				end
			end

			if steel_card_count > 0 then
				local multiplier_factor = 1 + effect.value
				local x_mult_steps = {}
				for _ = 1, steel_card_count do
					state.scores.x_mult[owner] = state.scores.x_mult[owner] * multiplier_factor
					x_mult_steps[#x_mult_steps + 1] = state.scores.x_mult[owner]
				end
				animations.add_animation("steel_sync_mult")(state, {
					owner = owner,
					steel_hand_indices = steel_hand_indices,
					factor = multiplier_factor,
					x_mult_steps = x_mult_steps,
				})
			end
		end,
	}
end

--- Create temporary stance effect builder.
--- Creates a temporary stance instance with a specified duration and effect.
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.create_temporary_stance(effect)
	return {
		type = "CREATE_TEMPORARY_STANCE",
		phase = effect.phase or "hand",
		value = effect.value,
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner)
			if not effect.value or not effect.value.stance_id or not effect.value.rounds then
				return
			end

			state.temporary_stances = state.temporary_stances or {}

			local ObjectInstance = require("single_game.resolver.ObjectInstance")

			local instance_id = "temp_stance_" .. state.turn_number .. "_" .. owner .. "_" .. #state.temporary_stances
			local temp_stance = ObjectInstance.new(
				instance_id,
				effect.value.stance_id,
				"temporary_stance",
				owner,
				"created",
				{ remaining_rounds = effect.value.rounds }
			)

			temp_stance.created_this_turn = true
			state.temporary_stances[#state.temporary_stances + 1] = temp_stance
		end,
	}
end

--- Copies effects from the first non-echo stance to the **right on the same player's panel** for the current scoring phase only.
--- Child effects run when their definition phase matches the active resolution phase; the echo row is ``queries.source_stance_entry`` (from ``state._stance_effect_order``). Populate resolution via the resolver before apply (tests set ``phase``, ``source_stance_index``, ``source_stance_slot_index``, and call ``stance_order.flatten_stances_for_resolve`` when needed).
--- @param effect table
--- @return table
function M.copy_right_effect(effect)
	local sub = effect.sub or effect.phase
	if sub == "distance" then
		sub = "territory"
	end
	return {
		type = "COPY_RIGHT_EFFECT",
		phase = sub,
		macro = effect.macro or "playing_stones",
		sub = sub,
		territory_step = effect.territory_step,
		value = effect.value,
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, _owner)
			local target, target_owner, target_def = helpers.get_copy_right_target(state)
			if not target or not target_def then
				return
			end
			local resolved_effects = helpers.get_target_effects(state, target_def, M.resolve)
			if not resolved_effects then
				return
			end
			helpers.apply_copied_effect(state, target, target_owner, resolved_effects)
		end,
	}
end

--- Builds resolved runtime effects for a stance definition (one table per effect def, nils omitted).
--- @param stance_type string
--- @return table
function M.resolve_stance_definition_effects(stance_type)
	local defs = require("objects.definitions.stances")
	local stance_def = defs[stance_type]
	local list = stance_def and stance_def.effects or {}
	local out = {}
	for i = 1, #list do
		local resolved = M.resolve(list[i])
		if resolved then
			out[#out + 1] = resolved
		end
	end
	return out
end


--- Adds an owner-scoped run-persistent counter.
--- @param effect table
--- @return table
function M.adjust_run_persistent_counter(effect)
	return {
		type = "ADJUST_RUN_PERSISTENT_COUNTER",
		phase = effect.phase or "mult",
		value = effect.value or {},
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner)
			local counter_key = effect.value.counter_key
			if not counter_key or owner == nil then
				return
			end
			state.run_state = state.run_state or {}
			state.run_state.counters = state.run_state.counters or {}
			state.run_state.counters[counter_key] = state.run_state.counters[counter_key] or { B = 0, W = 0 }
			local delta = effect.value.delta or 0
			local old = state.run_state.counters[counter_key][owner]
			local new_val = math.max(stance_params.stance_persistent_flux_counter_floor, old + delta)
			local effective = new_val - old
			state.run_state.counters[counter_key][owner] = new_val
			state.run_state.pending_counter_mult_delta = state.run_state.pending_counter_mult_delta or {}
			state.run_state.pending_counter_mult_delta[counter_key] = state.run_state.pending_counter_mult_delta[counter_key]
				or { B = 0, W = 0 }
			state.run_state.pending_counter_mult_delta[counter_key][owner] = state.run_state.pending_counter_mult_delta[counter_key][owner]
				+ effective
		end,
	}
end

--- Applies accumulated effective counter delta for this resolve to +mult (round 2+); clears that pending bucket for the owner.
--- @param effect table
--- @return table
function M.apply_run_persistent_pending_delta_as_mult(effect)
	return {
		type = "APPLY_RUN_PERSISTENT_PENDING_DELTA_AS_MULT",
		phase = effect.phase or "mult",
		value = effect.value or {},
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner)
			local counter_key = effect.value.counter_key
			if not counter_key or owner == nil then
				return
			end
			local pending = state.run_state and state.run_state.pending_counter_mult_delta
			local by_owner = pending and pending[counter_key]
			local delta = by_owner and by_owner[owner] or 0
			state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + delta
			if by_owner then
				by_owner[owner] = 0
			end
		end,
	}
end

--- Applies owner-scoped run-persistent counter to +mult.
--- @param effect table
--- @return table
function M.apply_run_persistent_counter_as_mult(effect)
	return {
		type = "APPLY_RUN_PERSISTENT_COUNTER_AS_MULT",
		phase = effect.phase or "mult",
		value = effect.value or {},
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner)
			local counter_key = effect.value.counter_key
			if not counter_key or owner == nil then
				return
			end
			local counters = state.run_state and state.run_state.counters
			local by_owner = counters and counters[counter_key]
			local bonus = by_owner and by_owner[owner] or 0
			state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + bonus
		end,
	}
end

--- Destroys a selected target stone with deterministic chance.
--- @param effect table
--- @return table
function M.destroy_selected_enemy_stone(effect)
	return {
		type = "DESTROY_SELECTED_ENEMY_STONE",
		phase = effect.phase or "points",
		value = effect.value or {},
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner)
			local target = queries.selected_target(state)
			if not target or not target.row or not target.col then
				return
			end
			local row = target.row
			local col = target.col
			local row_cells = state.board and state.board[row]
			if not row_cells then
				return
			end
			local cell = row_cells[col]
			if board.is_empty(cell) then
				return
			end
			local owner_color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
			if cell.color == owner_color then
				return
			end

			local chance_num = effect.value.chance_numerator or card_params.destroy_chance_numerator_default
			local chance_den = effect.value.chance_denominator or card_params.destroy_chance_denominator_default
			if chance_den <= 0 then
				return
			end
			local match_state = require("match_state")
			local roll = match_state.rng_next_int(state, chance_den)
			if roll > chance_num then
				return
			end

			state.board[row][col] = config.STONE_NONE
			local actor_side = owner == config.OWNER_BLACK and "black" or "white"
			local actor_state = match_state.player_for_color(state, actor_side)
			actor_state.prisoners = (actor_state.prisoners or 0) + 1
		end,
	}
end

--- Adds a permanent per-cell point bonus for board stone scoring.
--- @param effect table
--- @return table
function M.add_permanent_points_to_selected_stone(effect)
	return {
		type = "ADD_PERMANENT_POINTS_TO_SELECTED_STONE",
		phase = effect.phase or "points",
		value = effect.value or {},
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner)
			local target = queries.selected_target(state)
			if not target or not target.row or not target.col then
				return
			end
			local row = target.row
			local col = target.col
			local row_cells = state.board and state.board[row]
			if not row_cells then
				return
			end
			local cell = row_cells[col]
			if board.is_empty(cell) then
				return
			end
			state.board_stone_modifiers = state.board_stone_modifiers or {}
			local key = row .. ":" .. col
			state.board_stone_modifiers[key] = state.board_stone_modifiers[key] or { points_bonus = 0 }
			state.board_stone_modifiers[key].points_bonus = state.board_stone_modifiers[key].points_bonus
				+ (effect.value.points or card_params.forge_mark_points_default)
		end,
	}
end

local function first_target(state)
	local targets = queries.selected_targets(state)
	if not targets or #targets == 0 then
		return nil
	end
	return targets[1]
end

local function selected_stone_cell(state)
	local target = first_target(state) or queries.selected_target(state)
	if not target or target.object_type ~= "stone" then
		return nil, nil, nil
	end
	local row = target.row
	local col = target.col
	local row_cells = state.board and state.board[row]
	if not row_cells then
		return nil, nil, nil
	end
	local cell = row_cells[col]
	if board.is_empty(cell) then
		return nil, nil, nil
	end
	return row, col, cell
end

--- Damages selected stone by ``value.amount`` (default 1), removing it at 0 solidity.
--- @param effect table
--- @return table
function M.damage_selected_stone(effect)
	return {
		type = "DAMAGE_SELECTED_STONE",
		phase = effect.phase or "points",
		value = effect.value or {},
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state)
			local row, col, cell = selected_stone_cell(state)
			if not cell then
				return
			end
			local stone_solidity = require("objects.stone_solidity")
			local amount = effect.value.amount or 1
			local current = cell.solidity or stone_solidity.stone_max_solidity(cell.kind)
			local next_value = math.max(0, current - amount)
			if next_value <= 0 then
				state.board[row][col] = config.STONE_NONE
				return
			end
			cell.solidity = next_value
		end,
	}
end

--- Heals selected stone by ``value.amount`` (default 1), capped at max solidity.
--- @param effect table
--- @return table
function M.heal_selected_stone(effect)
	return {
		type = "HEAL_SELECTED_STONE",
		phase = effect.phase or "points",
		value = effect.value or {},
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state)
			local _, _, cell = selected_stone_cell(state)
			if not cell then
				return
			end
			local stone_solidity = require("objects.stone_solidity")
			local amount = effect.value.amount or 1
			local current = cell.solidity or stone_solidity.stone_max_solidity(cell.kind)
			local max_s = stone_solidity.stone_max_solidity(cell.kind)
			cell.solidity = math.min(max_s, current + amount)
		end,
	}
end

--- Adds money after selecting the required cards.
--- @param effect table
--- @return table
function M.add_money(effect)
	return {
		type = "ADD_MONEY",
		phase = effect.phase or "points",
		value = effect.value or {},
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner)
			local amount = effect.value.amount or 0
			local side = owner == config.OWNER_BLACK and "black" or "white"
			local player = require("match_state").player_for_color(state, side)
			player.resources.money = (player.resources.money or 0) + amount
		end,
	}
end

--- @param state table
--- @return table|nil
local function placement_coords(state)
	local move = state.last_opponent_move
	if move and move.row and move.col then
		return move.row, move.col
	end
	return nil, nil
end

--- @param state table
--- @return table
local function pattern_apply_keys(state)
	state.run_state = state.run_state or {}
	state.run_state.pattern_apply_keys = state.run_state.pattern_apply_keys or {}
	return state.run_state.pattern_apply_keys
end

--- Match-lifetime dedupe for pattern and wall placement bonuses (not cleared each resolve).
--- @param state table
--- @param key string
--- @return boolean already_seen
local function pattern_key_seen(state, key)
	local keys = pattern_apply_keys(state)
	if keys[key] then
		return true
	end
	keys[key] = true
	return false
end


--- @param state table
--- @return table board copy with the last placed stone removed
local function board_before_last_placement(state)
	local move = state.last_opponent_move
	if not move or not move.row or not move.col then
		return state.board
	end
	local b = board.clone(state.board)
	b[move.row][move.col] = config.STONE_NONE
	return b
end

--- When a placement raises an X pattern tier, multiply ``x_mult`` by 2 once per ``x_stone`` in that X.
--- @param effect table
--- @return table
function M.pattern_x_mult(effect)
	return {
		type = "PATTERN_X_MULT",
		phase = effect.sub or "mult",
		macro = effect.macro or "playing_stones",
		sub = effect.sub or "mult",
		priority = effect.priority or stone_params.pattern_effect_priority,
		conditions = effect.conditions,
		apply = function(state, owner)
			local color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
			local board_after = state.board
			local board_before = board_before_last_placement(state)
			local newly_completed = shape_patterns.detect_newly_completed_x_patterns(board_before, board_after, color)
			local place_r, place_c = placement_coords(state)
			for i = 1, #newly_completed do
				local pattern = newly_completed[i]
				local dedupe = "x:"
					.. pattern.center_row
					.. ":"
					.. pattern.center_col
					.. ":"
					.. pattern.tier
					.. ":"
					.. owner
				if not pattern_key_seen(state, dedupe) then
					local x_count = shape_patterns.count_x_stones_in_pattern(board_after, pattern)
					local factor = shape_patterns.x_mult_factor_for_x_stone_count(x_count)
					if x_count > 0 then
						state.scores.x_mult[owner] = state.scores.x_mult[owner] * factor
					end
					animations.add_animation("pattern_x_celebrate")(state, {
						owner = owner,
						cells = pattern.cells,
						board_after = board_after,
					})
				end
			end
		end,
	}
end

--- @param state table
--- @param board_after table
--- @param patterns table[]
--- @param owner string
--- @param place_r integer|nil
--- @param place_c integer|nil
--- @param placed_plus boolean
--- @return integer bonus applied
local function plus_mult_bonus_for_newly_completed_patterns(state, board_after, patterns, owner, place_r, place_c, placed_plus)
	state._pattern_plus_bonus_cells = state._pattern_plus_bonus_cells or {}
	local bonus = 0
	for pi = 1, #patterns do
		local pattern = patterns[pi]
		for ci = 1, #pattern.cells do
			local r, c = pattern.cells[ci][1], pattern.cells[ci][2]
			local cell = board_after[r][c]
			if cell and cell.kind == "plus_stone" then
				local is_placed = placed_plus and place_r == r and place_c == c
				local cell_key = owner .. ":" .. r .. ":" .. c
				if is_placed or not state._pattern_plus_bonus_cells[cell_key] then
					if not is_placed then
						state._pattern_plus_bonus_cells[cell_key] = true
					end
					bonus = bonus + stone_params.plus_stone_mult_add
				end
			end
		end
	end
	return bonus
end

--- When a placement raises a + pattern tier, add +5 per ``plus_stone`` in that + (shared cells once; placed ``plus_stone`` counts per +).
--- @param effect table
--- @return table
function M.pattern_plus_mult(effect)
	return {
		type = "PATTERN_PLUS_MULT",
		phase = effect.sub or "mult",
		macro = effect.macro or "playing_stones",
		sub = effect.sub or "mult",
		priority = effect.priority or stone_params.pattern_effect_priority,
		conditions = effect.conditions,
		apply = function(state, owner)
			local color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
			local board_after = state.board
			local board_before = board_before_last_placement(state)
			local newly_completed = shape_patterns.detect_newly_completed_plus_patterns(board_before, board_after, color)
			local place_r, place_c = placement_coords(state)
			local placed_plus = false
			if place_r and place_c then
				local placed = board_after[place_r][place_c]
				placed_plus = placed and placed.kind == "plus_stone"
			end
			local to_score = {}
			for i = 1, #newly_completed do
				local pattern = newly_completed[i]
				local dedupe = "plus:"
					.. pattern.center_row
					.. ":"
					.. pattern.center_col
					.. ":"
					.. pattern.tier
					.. ":"
					.. owner
				if not pattern_key_seen(state, dedupe) then
					to_score[#to_score + 1] = pattern
				end
			end
			local bonus = plus_mult_bonus_for_newly_completed_patterns(
				state,
				board_after,
				to_score,
				owner,
				place_r,
				place_c,
				placed_plus
			)
			if bonus > 0 then
				state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + bonus
			end
			for pi = 1, #to_score do
				local pattern = to_score[pi]
				animations.add_animation("pattern_plus_celebrate")(state, {
					owner = owner,
					cells = pattern.cells,
					board_after = board_after,
				})
			end
		end,
	}
end

--- Wall placement: +5 Points per 5 stones in the orthogonal connected group (wall included).
--- @param effect table
--- @return table
function M.wall_stone(effect)
	return {
		type = "WALL_STONE",
		phase = effect.sub or "points",
		macro = effect.macro or "playing_stones",
		sub = effect.sub or "points",
		priority = effect.priority or stone_params.wall_effect_priority,
		conditions = effect.conditions,
		apply = function(state, owner, row, col)
			if row == nil or col == nil then
				return
			end
			local place_r, place_c = placement_coords(state)
			if place_r and place_c and (place_r ~= row or place_c ~= col) then
				return
			end
			local cell = state.board[row] and state.board[row][col]
			if not cell or board.is_empty(cell) or cell.kind ~= "wall" then
				return
			end
			local dedupe = "wall:" .. row .. ":" .. col
			if pattern_key_seen(state, dedupe) then
				return
			end
			local group = shape_patterns.group_connected(state.board, row, col)
			local bonus = shape_patterns.wall_points_for_connected_group_size(#group)
			if bonus <= 0 then
				return
			end
			state.scores.points[owner] = state.scores.points[owner] + bonus
			animations.add_animation("wall_stone_bounce")(state, {
				owner = owner,
				cells = group,
				bonus = bonus,
				anchor_row = row,
				anchor_col = col,
			})
		end,
	}
end

--- Line stone placement: points per full block of orthogonal connected group (line stone included).
--- @param effect table
--- @return table
function M.line_group_points(effect)
	local stone_kind = effect.stone_kind or "line_stone"
	return {
		type = "LINE_GROUP_POINTS",
		phase = effect.sub or "points",
		macro = effect.macro or "playing_stones",
		sub = effect.sub or "points",
		priority = effect.priority or stone_params.wall_effect_priority,
		conditions = effect.conditions,
		apply = function(state, owner, row, col)
			if row == nil or col == nil then
				return
			end
			local place_r, place_c = placement_coords(state)
			if place_r and place_c and (place_r ~= row or place_c ~= col) then
				return
			end
			local cell = state.board[row] and state.board[row][col]
			if not cell or board.is_empty(cell) or cell.kind ~= stone_kind then
				return
			end
			local dedupe = "line:" .. row .. ":" .. col
			if pattern_key_seen(state, dedupe) then
				return
			end
			local group = shape_patterns.group_connected(state.board, row, col)
			local block = stone_params.line_stone_block_size
			local per_block = stone_params.line_stone_points_per_block
			local bonus = math.floor(#group / block) * per_block
			if bonus <= 0 then
				return
			end
			state.scores.points[owner] = state.scores.points[owner] + bonus
		end,
	}
end

--- Double corner nearby territory effect: corner tower adds ``1`` to ``territory_value`` on every cell in the
--- board-aligned ``3×3`` block anchored at that corner (excluding the tower cell). Stacks with prior cell values.
--- @param row integer
--- @param col integer
--- @param effect_def table
--- @return table
function M.double_corner_nearby_territory(row, col, effect_def)
	return {
		type = "DOUBLE_CORNER_NEARBY_TERRITORY",
		phase = "territory",
		macro = effect_def.macro or "playing_stones",
		sub = "territory",
		priority = effect_def.priority or 10,
		conditions = effect_def.conditions,
		apply = function(state, owner)
			local n = config.BOARD_SIZE
			local is_corner = (row == 1 or row == n) and (col == 1 or col == n)
			if not is_corner then
				return
			end
			state.territory_value = state.territory_value or {}
			local r0, r1, c0, c1
			if row == 1 and col == 1 then
				r0, r1, c0, c1 = 1, math.min(3, n), 1, math.min(3, n)
			elseif row == 1 and col == n then
				r0, r1, c0, c1 = 1, math.min(3, n), math.max(1, n - 2), n
			elseif row == n and col == 1 then
				r0, r1, c0, c1 = math.max(1, n - 2), n, 1, math.min(3, n)
			else
				r0, r1, c0, c1 = math.max(1, n - 2), n, math.max(1, n - 2), n
			end
			for tr = r0, r1 do
				state.territory_value[tr] = state.territory_value[tr] or {}
				for tc = c0, c1 do
					if tr ~= row or tc ~= col then
						local cur = state.territory_value[tr][tc] or 1
						state.territory_value[tr][tc] = cur + stone_params.stone_tower_corner_territory_add
					end
				end
			end
		end,
	}
end

--- Generic effect resolver: dispatch by effect_name.
--- Returns resolved effect with type, phase, priority, and apply function.
--- @param effect table: {effect_name, ...}
--- @return table|nil: resolved effect, or nil if unknown
function M.resolve(effect)
	if not effect or not effect.effect_name then
		return nil
	end
	local builder = M[effect.effect_name]
	if not builder then
		return nil
	end
	local resolved = builder(effect)
	if resolved then
		resolved._effect_def = effect
	end
	return resolved
end

--- Board effect builders registry.
local BOARD_EFFECT_BUILDERS = {
	double_corner_nearby_territory = function(row, col, effect_def)
		return M.double_corner_nearby_territory(row, col, effect_def)
	end,
}

--- Emit effects for a concrete stone instance on the board.
--- Handles distance-phase and territory-phase effects.
--- @param stone_cell table
--- @param row integer
--- @param col integer
--- @param state table
--- @return table array of effect entries
--- @param effect_def table
--- @param row integer
--- @param col integer
--- @param owner string
--- @return table|nil
local function resolve_board_effect_entry(effect_def, row, col, owner)
	if effect_def.effect_name == "distance_bonus" then
		return nil
	end
	local resolved = M.resolve(effect_def)
	if not resolved then
		return nil
	end
	local base_apply = resolved.apply
	if resolved.type == "WALL_STONE" or resolved.type == "LINE_GROUP_POINTS" then
		resolved.apply = function(current_state)
			base_apply(current_state, owner, row, col)
		end
	else
		resolved.apply = function(current_state)
			base_apply(current_state, owner)
		end
	end
	return resolved
end

--- Board-scoped stone effects only (no on-place add_points/add_mult).
--- @param stone_cell table
--- @param row integer
--- @param col integer
--- @param state table
--- @param active_macro string
--- @param active_sub string
--- @param territory_step string|nil
--- @return table
function M.resolve_board_stone(stone_cell, row, col, state, active_macro, active_sub, territory_step)
	local scoring_phases = require("single_game.resolver.scoring_phases")
	local content = require("content")
	local stone_def = content.get_stone(stone_cell.kind)
	local key = helpers.stone_key(row, col)
	local n = config.BOARD_SIZE
	local out = {}
	local effect_defs = {}
	local owner = stone_cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
	active_macro = active_macro or state._resolve_macro or "playing_stones"

	if stone_def and stone_def.effects then
		for i = 1, #stone_def.effects do
			effect_defs[#effect_defs + 1] = stone_def.effects[i]
		end
	end
	for i = 1, #shared_stones_effects.all_stone_board_effects do
		local shared_def = shared_stones_effects.all_stone_board_effects[i]
		if shared_def.effect_name ~= "pattern_x_mult" and shared_def.effect_name ~= "pattern_plus_mult" then
			effect_defs[#effect_defs + 1] = shared_def
		end
	end

	for _, effect_def in ipairs(effect_defs) do
		if scoring_phases.is_placement_only_effect_name(effect_def.effect_name) then
		elseif not scoring_phases.matches(effect_def, active_macro, active_sub, territory_step) then
		elseif effect_def.effect_name == "distance_bonus" then
			out[#out + 1] = {
				type = "DISTANCE_BONUS",
				phase = "territory",
				sub = "territory",
				macro = active_macro,
				priority = effect_def.priority or 10,
				conditions = effect_def.conditions,
				apply = function(current_state)
					helpers.apply_distance_bonus_for_stone(
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
		else
			local resolved = resolve_board_effect_entry(effect_def, row, col, owner)
			if resolved then
				resolved.macro = active_macro
				resolved.sub = active_sub
				out[#out + 1] = resolved
			end
		end
	end

	return out
end

--- Resolves card definition effects.
--- @param card table
--- @return table
function M.resolve_card_effects(card)
	local defs = require("objects.definitions.cards")
	local card_def = defs[card.type]
	if not card_def or not card_def.effects then
		return {}
	end
	local out = {}
	for i = 1, #card_def.effects do
		local resolved = M.resolve(card_def.effects[i])
		if resolved then
			out[#out + 1] = resolved
		end
	end
	return out
end

return M