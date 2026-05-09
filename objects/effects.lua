--- Unified effect operation registry.
--- Consolidated from individual stone/card/stance modules for PR 3 unification.
--- Single dispatcher for all effect types across the game.
--- @module objects.effects

local config = require("config")
local board = require("board")
local queries = require("single_game.resolver.state_queries")

local M = {}

--- Resolves blueprint copy target by scanning right and skipping blueprints.
--- @param state table
--- @param start_index integer
--- @return table|nil
local function resolve_blueprint_target(state, start_index)
	local ordered = state and state.stances or {}
	local i = (start_index or 0) + 1
	while i <= #ordered do
		local target = ordered[i]
		if target and target.type ~= "stance_blueprint" then
			return target
		end
		i = i + 1
	end
	return nil
end

--- @param owner string
--- @return string
local function normalize_stance_owner(owner)
	local preserved = (owner == "A" or owner == "B") and owner or nil
	return preserved or ((owner == "white" or owner == "B") and "B" or "A")
end

--- Add points effect builder.
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.add_points(effect)
	return {
		type = "ADD_POINTS",
		phase = effect.phase or "points",
		value = effect.value,
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner, context)
			state.scores.points[owner] = state.scores.points[owner] + effect.value
		end,
	}
end

--- Add multiplier effect builder.
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.add_mult(effect)
	return {
		type = "ADD_MULT",
		phase = effect.phase or "mult",
		value = effect.value,
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, owner, context)
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
		phase = "distance",
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
		apply = function(state, owner, context)
			context = context or {}
			local match_state = require("match_state")
			local player_state = match_state.player_for_color(state, owner == "A" and "black" or "white")
			if not player_state then
				return
			end

			local hand_ids = player_state.cards.hand and player_state.cards.hand.ids
			if not hand_ids then
				return
			end

			local content = require("content")
			local steel_card_count = 0
			for _, card_id in ipairs(hand_ids) do
				if card_id then
					local card_def = content.get_card(card_id)
					if card_def and card_def.tags then
						for _, tag in ipairs(card_def.tags) do
							if tag == "steel" then
								steel_card_count = steel_card_count + 1
								break
							end
						end
					end
				end
			end

			if steel_card_count > 0 then
				local multiplier_factor = 1 + effect.value
				for _ = 1, steel_card_count do
					state.scores.x_mult[owner] = state.scores.x_mult[owner] * multiplier_factor
				end
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
		apply = function(state, owner, context)
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

--- Copies effects from the first non-blueprint stance to the right for the current scoring phase only.
--- Child effects run when ``queries.resolution_phase`` matches each child effect phase; originating stance row comes from ``queries.source_stance_entry`` (`state.resolution.source_stance_index`). Populate resolution via the resolver before apply (standalone tests use ``state_queries.ensure_resolution`` and set ``phase`` / ``source_stance_index`` accordingly).
--- @param effect table
--- @return table
function M.copy_right_stance_effects(effect)
	return {
		type = "COPY_RIGHT_STANCE_EFFECTS",
		phase = effect.phase or "points",
		value = effect.value,
		priority = effect.priority or 10,
		conditions = effect.conditions,
		apply = function(state, _blueprint_owner, context)
			local conditions_mod = require("objects.conditions")
			local phase = queries.resolution_phase(state)
			local stance_entry = queries.source_stance_entry(state)
			if context and context.phase then
				phase = context.phase
			end
			if context and context.stance_entry then
				stance_entry = context.stance_entry
			end
			if not phase or not stance_entry then
				return
			end
			local target = resolve_blueprint_target(state, stance_entry.index)
			if not target then
				return
			end
			local target_owner = normalize_stance_owner(target.owner)
			local defs = require("objects.definitions.stances")
			local target_def = defs[target.type]
			if not target_def or not target_def.effects then
				return
			end
			for i = 1, #target_def.effects do
				local effect_def = target_def.effects[i]
				if effect_def.effect_name ~= "copy_right_stance_effects" then
					local resolved = M.resolve(effect_def)
					if resolved and resolved.phase == phase and resolved.apply then
						local resolution = queries.ensure_resolution(state)
						local prev_source_owner = resolution.source_owner
						local prev_stance_index = resolution.source_stance_index
						local prev_instance_id = resolution.source_instance_id
						local prev_def_id = resolution.source_def_id
						local prev_type = resolution.source_object_type
						resolution.source_owner = target_owner
						resolution.source_stance_index = nil
						resolution.source_instance_id = target.instance and target.instance.instance_id or nil
						resolution.source_def_id = target.type
						resolution.source_object_type = "stance"
						if conditions_mod.eval_all(resolved.conditions, state) then
							resolved.apply(state, target_owner, nil)
						end
						resolution.source_owner = prev_source_owner
						resolution.source_stance_index = prev_stance_index
						resolution.source_instance_id = prev_instance_id
						resolution.source_def_id = prev_def_id
						resolution.source_object_type = prev_type
					end
				end
			end
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
		apply = function(state, owner, context)
			local counter_key = effect.value.counter_key
			if not counter_key or owner == nil then
				return
			end
			state.run_state = state.run_state or {}
			state.run_state.counters = state.run_state.counters or {}
			state.run_state.counters[counter_key] = state.run_state.counters[counter_key] or { A = 0, B = 0 }
			local delta = effect.value.delta or 0
			state.run_state.counters[counter_key][owner] = state.run_state.counters[counter_key][owner] + delta
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
		apply = function(state, owner, context)
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
		apply = function(state, owner, context)
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
			local owner_color = owner == "A" and config.STONE_BLACK or config.STONE_WHITE
			if cell.color == owner_color then
				return
			end

			local chance_num = effect.value.chance_numerator or 1
			local chance_den = effect.value.chance_denominator or 4
			if chance_den <= 0 then
				return
			end
			local match_state = require("match_state")
			local roll = match_state.rng_next_int(state, chance_den)
			if roll > chance_num then
				return
			end

			state.board[row][col] = config.STONE_NONE
			local actor_side = owner == "A" and "black" or "white"
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
		apply = function(state, owner, context)
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
			state.board_stone_modifiers[key].points_bonus = state.board_stone_modifiers[key].points_bonus + (effect.value.points or 10)
		end,
	}
end

--- Double corner nearby territory effect (special board effect).
--- @param row integer
--- @param col integer
--- @param effect_def table
--- @return table
function M.double_corner_nearby_territory(row, col, effect_def)
	return {
		type = "DOUBLE_CORNER_NEARBY_TERRITORY",
		phase = "territory",
		priority = effect_def.priority or 10,
		conditions = effect_def.conditions,
		apply = function(state, owner, context)
			local n = config.BOARD_SIZE
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
	return builder(effect)
end

--- Stone key generator for distance modifier indexing.
--- @param row integer
--- @param col integer
--- @return integer
local function stone_key(row, col)
	return row * 100 + col
end

--- Apply distance bonus for a stone across all tiles.
--- @param stone_def table
--- @param current_state table
--- @param key integer
--- @param n integer
--- @param distance_bonus_value integer
--- @return nil
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
					type = "DISTANCE_BONUS",
					phase = "distance",
					priority = effect_def.priority or 10,
					conditions = effect_def.conditions,
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
