--- Unified effect operation registry.
--- Consolidated from individual stone/card/stance modules for PR 3 unification.
--- Single dispatcher for all effect types across the game.
--- @module objects.effects_conditions.effects

local config = require("config")
local board = require("board")
local queries = require("single_game.resolver.helpers.state_queries")
local helpers = require("objects.effects_conditions.helpers.shared.effects_helpers")
local animations = require("objects.animations")
local shape_patterns = require("game.patterns.shape_patterns")
local stone_params = require("objects.parameters.stones")
local stance_params = require("objects.parameters.stances")
local card_params = require("objects.parameters.cards")
local enclosure = require("single_game.resolver.enclosure")
local rules = require("rules")
local EffectSchema = require("objects.effects_conditions.EffectSchema")
local scheduling = EffectSchema.schedule
local require_kwargs = require("objects.effects_conditions.helpers.shared.require_kwargs")
local dispatch_removed = require("single_game.resolver.stages.dispatch_removed")

local M = {}

local function cell_key(r, c)
	return r * 100 + c
end

--- @param fields table[]
--- @return table<integer, boolean>
local function inside_field_set(fields)
	local set = {}
	for i = 1, #fields do
		local field = fields[i]
		set[cell_key(field[1], field[2])] = true
	end
	return set
end

--- @param wall table
--- @param r integer
--- @param c integer
--- @return boolean
local function wall_contains_cell(wall, r, c)
	return inside_field_set(wall.inside_fields)[cell_key(r, c)] == true
end

--- @param inner table<integer, boolean>
--- @param outer table<integer, boolean>
--- @return boolean
local function inside_set_is_strict_subset(inner, outer)
	for key in pairs(inner) do
		if not outer[key] then
			return false
		end
	end
	for key in pairs(outer) do
		if not inner[key] then
			return true
		end
	end
	return false
end

--- @param wall table
--- @param row integer
--- @param col integer
--- @return boolean
local function stone_triggers_wall(wall, row, col)
	if wall_contains_cell(wall, row, col) then
		return true
	end
	if enclosure.cell_in_wall_interior(wall, row, col, config.BOARD_SIZE) then
		return true
	end
	local inside = inside_field_set(wall.inside_fields)
	local ortho = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
	for i = 1, #ortho do
		local nr, nc = row + ortho[i][1], col + ortho[i][2]
		if inside[cell_key(nr, nc)] then
			return true
		end
	end
	return false
end

--- @param wall table
--- @param row integer
--- @param col integer
--- @return boolean
local function stone_on_wall_boundary(wall, row, col)
	for i = 1, #wall.boundary_fields do
		local field = wall.boundary_fields[i]
		if field[1] == row and field[2] == col then
			return true
		end
	end
	return false
end

--- @param walls table[]
--- @param owner string
--- @param row integer
--- @param col integer
--- @param n integer
--- @return table|nil
local function smallest_containing_wall(walls, owner, row, col, n)
	local triggered = {}
	for i = 1, #walls do
		local wall = walls[i]
		if wall.owner == owner and stone_triggers_wall(wall, row, col) then
			triggered[#triggered + 1] = wall
		end
	end
	local largest_count = 0
	for i = 1, #triggered do
		if triggered[i].field_count > largest_count then
			largest_count = triggered[i].field_count
		end
	end
	local best = nil
	for i = 1, #triggered do
		local wall = triggered[i]
		if stone_on_wall_boundary(wall, row, col) and wall.field_count < largest_count then
		else
			if not best or wall.field_count < best.field_count then
				best = wall
			end
		end
	end
	return best
end

--- @param board table
--- @param wall table
--- @param stone_kind string
--- @param owner string
--- @return boolean
local function wall_contains_matching_enclosure_stone(b, wall, stone_kind, owner)
	local owner_color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) and cell.kind == stone_kind and cell.color == owner_color then
				if stone_triggers_wall(wall, r, c) then
					return true
				end
			end
		end
	end
	return false
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return string|nil
local function empty_region_owner(state, row, col)
	local tiles = state.territory_tiles
	local regions = state.regions
	if not tiles or not regions then
		return nil
	end
	local tile = tiles[row] and tiles[row][col]
	local region_id = tile and tile.region_id
	if not region_id then
		return nil
	end
	local region = regions[region_id]
	return region and region.owner or nil
end

--- @param b table
--- @param stone_kind string
--- @param owner string
--- @return boolean
local function opponent_has_enclosure_stone(b, stone_kind, owner)
	local opponent_color = owner == config.OWNER_BLACK and config.STONE_WHITE or config.STONE_BLACK
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) and cell.kind == stone_kind and cell.color == opponent_color then
				return true
			end
		end
	end
	return false
end

--- @param targets table<integer, boolean>
--- @param state table
--- @param owner string
--- @return table<integer, boolean>
local function filter_targets_by_region_owner(targets, state, owner)
	local filtered = {}
	for key in pairs(targets) do
		local tr = math.floor(key / 100)
		local tc = key % 100
		local region_owner = empty_region_owner(state, tr, tc)
		if region_owner == nil or region_owner == owner then
			filtered[key] = true
		end
	end
	return filtered
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param owner string
--- @param n integer
--- @return table<integer, boolean>
--- @return boolean touches_board_edge
local function flood_passable_for_owner(b, row, col, owner, n)
	local owner_color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
	local visited = {}
	local touches_board_edge = false
	local queue = {}
	local function passable(r, c)
		local cell = b[r][c]
		return board.is_empty(cell) or cell.color ~= owner_color
	end
	local function enqueue_passable(r, c)
		if r < 1 or r > n or c < 1 or c > n then
			return
		end
		local key = cell_key(r, c)
		if visited[key] or not passable(r, c) then
			return
		end
		visited[key] = true
		if r == 1 or r == n or c == 1 or c == n then
			touches_board_edge = true
		end
		queue[#queue + 1] = { r, c }
	end
	local ortho = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
	if passable(row, col) then
		enqueue_passable(row, col)
	else
		for i = 1, #ortho do
			enqueue_passable(row + ortho[i][1], col + ortho[i][2])
		end
	end
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		for i = 1, #ortho do
			enqueue_passable(cur[1] + ortho[i][1], cur[2] + ortho[i][2])
		end
	end
	return visited, touches_board_edge
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param n integer
--- @return table<integer, boolean>
--- @return boolean touches_board_edge
local function flood_empty_enclosure_from_stone(b, row, col, n)
	local visited = {}
	local targets = {}
	local touches_board_edge = false
	local queue = {}
	local function enqueue_empty(r, c)
		if r < 1 or r > n or c < 1 or c > n then
			return
		end
		local key = cell_key(r, c)
		if visited[key] then
			return
		end
		if not board.is_empty(b[r][c]) then
			return
		end
		visited[key] = true
		if r == 1 or r == n or c == 1 or c == n then
			touches_board_edge = true
		end
		targets[key] = true
		queue[#queue + 1] = { r, c }
	end
	local ortho = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
	for i = 1, #ortho do
		enqueue_empty(row + ortho[i][1], col + ortho[i][2])
	end
	local head = 1
	while head <= #queue do
		local cur = queue[head]
		head = head + 1
		for i = 1, #ortho do
			enqueue_empty(cur[1] + ortho[i][1], cur[2] + ortho[i][2])
		end
	end
	return targets, touches_board_edge
end

--- @param inner_set table<integer, boolean>
--- @param outer_set table<integer, boolean>
--- @param walls table[]
--- @return boolean
local function is_immediate_interior_subset(inner_set, outer_set, walls)
	for i = 1, #walls do
		local between = inside_field_set(walls[i].inside_fields)
		if inside_set_is_strict_subset(between, outer_set)
			and inside_set_is_strict_subset(inner_set, between) then
			return false
		end
	end
	return true
end

--- @param b table
--- @param cell_set table<integer, boolean>
--- @return table<integer, boolean>
local function empty_cells_in_set(b, cell_set)
	local targets = {}
	for key in pairs(cell_set) do
		local r = math.floor(key / 100)
		local c = key % 100
		if board.is_empty(b[r][c]) then
			targets[key] = true
		end
	end
	return targets
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param owner string
--- @return boolean
local function empty_cell_in_opponent_ring(b, row, col, owner)
	local opponent_color = owner == config.OWNER_BLACK and config.STONE_WHITE or config.STONE_BLACK
	local n = config.BOARD_SIZE
	local ortho = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
	for i = 1, #ortho do
		local nr, nc = row + ortho[i][1], col + ortho[i][2]
		if nr < 1 or nr > n or nc < 1 or nc > n then
			return false
		end
		local cell = b[nr][nc]
		if board.is_empty(cell) or cell.color ~= opponent_color then
			return false
		end
	end
	return true
end

--- @param b table
--- @param other_set table<integer, boolean>
--- @param owner string
--- @return boolean
local function opponent_pocket_fully_ringed(b, other_set, owner)
	for key in pairs(other_set) do
		local row = math.floor(key / 100)
		local col = key % 100
		if not empty_cell_in_opponent_ring(b, row, col, owner) then
			return false
		end
	end
	return true
end

--- @param walls table[]
--- @param board table
--- @param owner string
--- @param stone_kind string
--- @param primary_set table<integer, boolean>
--- @param exclude_opponent_pockets boolean
--- @return table<integer, boolean>
local function enclosure_multiply_target_keys(walls, b, owner, stone_kind, primary_set, exclude_opponent_pockets)
	local targets = {}
	for key in pairs(primary_set) do
		targets[key] = true
	end
	for i = 1, #walls do
		local other = walls[i]
		local other_set = inside_field_set(other.inside_fields)
		if inside_set_is_strict_subset(other_set, primary_set) then
			local exclude = false
			if exclude_opponent_pockets and other.owner ~= owner and #other.inside_fields > 0
				and opponent_pocket_fully_ringed(b, other_set, owner) then
				exclude = true
			elseif other.owner == owner and wall_contains_matching_enclosure_stone(b, other, stone_kind, owner) then
				if not is_immediate_interior_subset(other_set, primary_set, walls) then
					exclude = true
				end
			end
			if exclude then
				for key in pairs(other_set) do
					targets[key] = nil
				end
			end
		end
	end
	return targets
end

--- @param walls table[]
--- @param board table
--- @param owner string
--- @param row integer
--- @param col integer
--- @param stone_kind string
--- @return table<integer, boolean>
local function resolve_enclosure_multiply_targets(walls, b, owner, row, col, stone_kind)
	local n = config.BOARD_SIZE
	local primary_wall = smallest_containing_wall(walls, owner, row, col, n)
	local flood_targets, touches_board_edge = flood_empty_enclosure_from_stone(b, row, col, n)
	local primary_set
	local exclude_opponent_pockets = false
	if primary_wall then
		local wall_set = inside_field_set(primary_wall.inside_fields)
		local wall_empty = empty_cells_in_set(b, wall_set)
		local wall_empty_count = 0
		for _ in pairs(wall_empty) do
			wall_empty_count = wall_empty_count + 1
		end
		local flood_count = 0
		for _ in pairs(flood_targets) do
			flood_count = flood_count + 1
		end
		if flood_count > wall_empty_count and not touches_board_edge then
			local _, passable_touches_edge = flood_passable_for_owner(b, row, col, owner, n)
			if not passable_touches_edge then
				primary_set = flood_targets
				exclude_opponent_pockets = true
			else
				primary_set = wall_set
			end
		else
			primary_set = wall_set
		end
	else
		local _, passable_touches_edge = flood_passable_for_owner(b, row, col, owner, n)
		if passable_touches_edge then
			return {}
		end
		exclude_opponent_pockets = true
		if not touches_board_edge then
			primary_set = flood_targets
		else
			return {}
		end
	end
	if not primary_set or not next(primary_set) then
		return {}
	end
	local targets = enclosure_multiply_target_keys(
		walls,
		b,
		owner,
		stone_kind,
		primary_set,
		exclude_opponent_pockets
	)
	return empty_cells_in_set(b, targets)
end

--- Add points effect builder.
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.add_points(effect)
	return EffectSchema.build(effect, {
		type = "ADD_POINTS",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		kwargs_from_def = function(def)
			return { value = def.value }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "value" })
			state.scores.points[owner] = state.scores.points[owner] + kwargs.value
		end,
	})
end


--- Add energy effect builder (on placement; clamped to energy_max).
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.add_energy(effect)
	return EffectSchema.build(effect, {
		type = "ADD_ENERGY",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		kwargs_from_def = function(def)
			return { value = def.value }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "value" })
			helpers.gain_player_energy(state, owner, kwargs.value)
		end,
	})
end


--- Kamikaze sacrifice: points in apply; removal in ``remove_stones`` stage.
--- @param effect table: {effect_name, macro?, phase?, value?, priority?, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.kamikaze_sacrifice(effect)
	return EffectSchema.build(effect, {
		type = "KAMIKAZE_SACRIFICE",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		kwargs_from_def = function(def)
			return { value = def.value or stone_params.kamikaze_points_bonus }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "value" })
			state.scores.points[owner] = state.scores.points[owner] + kwargs.value
		end,
	})
end


--- Add multiplier effect builder.
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply}
function M.add_mult(effect)
	return EffectSchema.build(effect, {
		type = "ADD_MULT",
		default_phase = scheduling.PHASE.mult,
		default_action = scheduling.ACTION.on_play,
		kwargs_from_def = function(def)
			return { value = def.value }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "value" })
			state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + kwargs.value
		end,
	})
end


--- Distance bonus effect builder (no apply; used for state precomputation).
--- @param effect table: {effect_name, phase, value, priority, conditions?}
--- @return table: {type, phase, value, priority, conditions?, apply?}
function M.distance_bonus(effect)
	return EffectSchema.build(effect, {
		type = "DISTANCE_BONUS",
		default_phase = scheduling.PHASE.territory,
		default_action = scheduling.ACTION.on_play,
		extra = { territory_step = effect.territory_step or "distance" },
		skip_apply = true,
	})
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
	return EffectSchema.build(effect, {
		type = "COPY_RIGHT_EFFECT",
		default_phase = effect.phase == "distance" and scheduling.PHASE.territory or (effect.phase or scheduling.PHASE.points),
		default_action = scheduling.ACTION.on_play,
		extra = { territory_step = effect.territory_step },
		apply = function(state, _owner, _kwargs)
			local copy_right = require("objects.effects_conditions.helpers.shared.copy_right")
			copy_right.apply_copy_right(state, M.resolve)
		end,
	})
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

			local old_board = board.clone(state.board)
			local actor_side = owner == config.OWNER_BLACK and "black" or "white"
			state.board[row][col] = config.STONE_NONE
			dispatch_removed.run(state, old_board, state.board, { capturer = actor_side })
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
			local previous_bonus = cell._defence_solidity_bonus or 0
			local intrinsic = current - previous_bonus
			local next_intrinsic = math.max(0, intrinsic - amount)
			if next_intrinsic <= 0 then
				local old_board = board.clone(state.board)
				local resolution = queries.ensure_resolution(state)
				local capturer = resolution.effect_owner == config.OWNER_WHITE and "white" or "black"
				state.board[row][col] = config.STONE_NONE
				dispatch_removed.run(state, old_board, state.board, { capturer = capturer })
				return
			end
			cell.solidity = next_intrinsic + previous_bonus
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
	return EffectSchema.build(effect, {
		type = "ADD_MONEY",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		kwargs_from_def = function(def)
			return { amount = (def.value or {}).amount or 0 }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "amount" })
			local side = owner == config.OWNER_BLACK and "black" or "white"
			local player = require("match_state").player_for_color(state, side)
			player.resources.money = math.max(0, (player.resources.money or 0) + kwargs.amount)
		end,
	})
end

--- Each owner end_of_turn: add ``ems_round_money`` to owner money and track cumulative received on this cell.
--- @param effect table
--- @return table
function M.escalating_money_tracker(effect)
	return EffectSchema.build(effect, {
		type = "ESCALATING_MONEY_TRACKER",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.end_of_turn,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			local row = kwargs.row
			local col = kwargs.col
			local cell = state.board[row] and state.board[row][col]
			if not cell or board.is_empty(cell) or cell.kind ~= "escalating_money_stone" then
				return
			end
			local stone_owner = cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
			if stone_owner ~= owner then
				return
			end
			if cell.placed_turn_number ~= nil and cell.placed_turn_number == (state.turn_number or 1) then
				return
			end
			if state._skip_board_end_of_turn_effects then
				return
			end
			local economy = require("economy")
			local side = owner == config.OWNER_WHITE and "white" or "black"
			local player = require("match_state").player_for_color(state, side)
			local round_money = stone_params.ems_round_money
			economy.gain(player.resources, round_money)
			local next_total = (helpers.stone_stored_value(state, row, col) or 0) + round_money
			helpers.set_stone_stored_value(state, row, col, next_total)
		end,
	})
end


--- On removal: stone owner pays ``ems_capture_multiplier`` times cumulative received unless self-removal exempt.
--- @param effect table
--- @return table
function M.escalating_money_capture_penalty(effect)
	return EffectSchema.build(effect, {
		type = "ESCALATING_MONEY_CAPTURE_PENALTY",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_removed,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, _owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col", "cell" })
			local row = kwargs.row
			local col = kwargs.col
			local cell = kwargs.cell
			if not cell or board.is_empty(cell) then
				return
			end
			local received = helpers.stone_stored_value(state, row, col) or 0
			if cell.placed_via_play and received <= stone_params.ems_round_money then
				helpers.set_stone_stored_value(state, row, col, 0)
				return
			end
			if received <= 0 then
				helpers.set_stone_stored_value(state, row, col, 0)
				return
			end
			local side = cell.color == config.STONE_WHITE and "white" or "black"
			local player = require("match_state").player_for_color(state, side)
			local penalty = stone_params.ems_capture_multiplier * received
			require("economy").deduct_clamped(player.resources, penalty)
			helpers.set_stone_stored_value(state, row, col, 0)
		end,
	})
end


--- Adds money when the last placement cell is owner-enclosed on the post-placement board.
--- @param effect table
--- @return table
function M.money_field_enclosure_payout(effect)
	return EffectSchema.build(effect, {
		type = "MONEY_FIELD_ENCLOSURE_PAYOUT",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			local row, col = helpers.placement_coords(state)
			if not row or not col then
				return
			end
			local enclosure_placement = require("single_game.resolver.enclosure_placement")
			local amount = enclosure_placement.placement_money_payout(state.board, row, col, owner)
			if amount <= 0 then
				return
			end
			local side = owner == config.OWNER_BLACK and "black" or "white"
			local player = require("match_state").player_for_color(state, side)
			player.resources.money = (player.resources.money or 0) + amount
		end,
	})
end


--- @param state table
--- @return table
local function pattern_apply_keys(state)
	state.run_state = state.run_state or {}
	state.run_state.pattern_apply_keys = state.run_state.pattern_apply_keys or {}
	return state.run_state.pattern_apply_keys
end

--- Match-lifetime dedupe for pattern placement bonuses (not cleared each resolve).
--- @param state table
--- @param key string
--- @return boolean already_seen
local function pattern_key_seen(state, key)
	if state._retrigger_replay_depth and state._retrigger_replay_depth > 0 then
		return false
	end
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
		phase = effect.phase or "mult",
		priority = effect.priority or stone_params.pattern_effect_priority,
		conditions = effect.conditions,
		apply = function(state, owner)
			local color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
			local board_after = state.board
			local board_before = board_before_last_placement(state)
			local newly_completed = shape_patterns.detect_newly_completed_x_patterns(board_before, board_after, color)
			local place_r, place_c = helpers.placement_coords(state)
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
		phase = effect.phase or "mult",
		priority = effect.priority or stone_params.pattern_effect_priority,
		conditions = effect.conditions,
		apply = function(state, owner)
			local color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
			local board_after = state.board
			local board_before = board_before_last_placement(state)
			local newly_completed = shape_patterns.detect_newly_completed_plus_patterns(board_before, board_after, color)
			local place_r, place_c = helpers.placement_coords(state)
			local placed_plus = false
			if place_r and place_c then
				local placed = board_after[place_r][place_c]
				placed_plus = placed and not board.is_empty(placed) and placed.kind == "plus_stone"
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

--- Diagonal placement: points per block for the diagonally connected same-color group.
--- @param effect table
--- @return table
function M.diagonal_group_points(effect)
	return EffectSchema.build(effect, {
		type = "DIAGONAL_GROUP_POINTS",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.wall_effect_priority,
		apply = function(state, owner, kwargs)
			require("objects.effects_conditions.helpers.shared.connected_group_placement").apply_diagonal(state, owner)
		end,
	})
end


--- Board connectivity effect: one-shot defence solidity buff on connected own stones.
--- @param effect table
--- @return table
function M.defence_solidity_network(effect)
	return EffectSchema.build(effect, {
		type = "DEFENCE_SOLIDITY_NETWORK",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, _owner, row, col)
			if row == nil or col == nil then
				row, col = helpers.placement_coords(state)
			end
			if row and col then
				require("objects.defence_solidity_network").apply_on_play(state, row, col)
			end
		end,
	})
end

--- Shared on-play buff when a stone joins an existing defence network.
--- @param effect table
--- @return table
function M.defence_adjacency_solidity(effect)
	return EffectSchema.build(effect, {
		type = "DEFENCE_ADJACENCY_SOLIDITY",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, _owner, row, col)
			if row == nil or col == nil then
				row, col = helpers.placement_coords(state)
			end
			if row and col then
				require("objects.defence_solidity_network").apply_adjacency_on_play(state, row, col)
			end
		end,
	})
end

--- Marker for capture stone; removal handled in ``remove_stones`` stage.
--- @param effect table
--- @return table
function M.capture_zero_liberty_enemy(effect)
	return EffectSchema.build(effect, {
		type = "CAPTURE_ZERO_LIBERTY_ENEMY",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(_state, _owner, _kwargs)
		end,
	})
end


--- Delayed payout after ``survival_rounds_remaining`` on the stone cell reaches zero.
--- @param effect table
--- @return table
function M.delay_reward_survival(effect)
	return EffectSchema.build(effect, {
		type = "DELAY_REWARD_SURVIVAL",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		kwargs_from_def = function(def)
			return {
				rounds = def.rounds or stone_params.points_delay_rounds,
				payout = def.payout or stone_params.points_delay_payout,
			}
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "rounds", "payout" })
			local row = kwargs.row
			local col = kwargs.col
			if row == nil or col == nil then
				row, col = helpers.placement_coords(state)
			end
			if row == nil or col == nil then
				return
			end
			local cell = state.board[row] and state.board[row][col]
			if not cell or board.is_empty(cell) then
				return
			end
			cell.survival_rounds_remaining = kwargs.rounds
			cell.delay_payout = kwargs.payout
			cell.timer_remaining_rounds = kwargs.rounds
			state._effect_tick_skip_cell = { row = row, col = col }
		end,
		on_tick = function(state, row, col, cell)
			if type(cell.survival_rounds_remaining) == "number" and cell.survival_rounds_remaining > 0 then
				return
			end
			if cell.delay_payout == nil then
				return
			end
			local payout_amount = cell.delay_payout or stone_params.points_delay_payout
			cell.delay_payout = nil
			cell.survival_rounds_remaining = nil
			cell.timer_remaining_rounds = nil
			if board.is_empty(cell) or payout_amount <= 0 then
				return
			end
			local payout_owner = cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
			state.scores.points[payout_owner] = state.scores.points[payout_owner] + payout_amount
		end,
	})
end


function M.anti_capture_immunity(effect)
	return EffectSchema.build(effect, {
		type = "ANTI_CAPTURE_IMMUNITY",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		kwargs_from_def = function(def)
			return { duration = def.duration or stone_params.anti_capture_duration_rounds }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "duration" })
			local row, col = helpers.placement_coords(state)
			if row == nil or col == nil then
				return
			end
			state._anti_capture_board_snapshot_seeded = true
			local group = rules.collect_group(state.board, row, col)
			for i = 1, #group do
				local r, c = group[i][1], group[i][2]
				local cell = state.board[r][c]
				if cell and not board.is_empty(cell) then
					cell.immunity_remaining = kwargs.duration
				end
			end
		end,
		on_tick = function(_state, _row, _col, cell)
			local remaining = cell.immunity_remaining
			if type(remaining) == "number" and remaining > 0 then
				return
			end
			cell.immunity_remaining = nil
		end,
	})
end


--- On placement, block opponent on orthogonally adjacent empty cells for ``blockade_duration_rounds``.
--- Board-zone durations live in ``placement_blocks`` (see ``blocked_cells`` module).
--- @param effect table
--- @return table
function M.blockade_adjacent(effect)
	return EffectSchema.build(effect, {
		type = "BLOCKADE_ADJACENT",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			local row, col = helpers.placement_coords(state)
			if row == nil or col == nil then
				return
			end
			local actor = owner == config.OWNER_BLACK and "black" or "white"
			require("single_game.resolver.helpers.blocked_cells").register_adjacent_from_blockade(state, row, col, actor)
			state._blockade_registered_this_action = true
		end,
		on_tick = function(state)
			require("single_game.resolver.helpers.blocked_cells").tick(state)
		end,
	})
end


--- End-of-turn tax from enemy stones inside the innermost owner enclosure containing this tax stone.
--- @param effect table
--- @return table
function M.tax_enclosure_enemies(effect)
	return EffectSchema.build(effect, {
		type = "TAX_ENCLOSURE_ENEMIES",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.end_of_turn,
		default_priority = stone_params.default_effect_priority,
		kwargs_from_def = function(def)
			return { value = def.value or {} }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			local active_owner = helpers.active_end_of_turn_owner(state)
			if not active_owner or owner ~= active_owner then
				return
			end
			local row = kwargs.row
			local col = kwargs.col
			local value = kwargs.value or {}
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
			local money_per = value.money_per_enemy or stone_params.tax_money_per_enemy
			local points_per = value.points_per_enemy or stone_params.tax_points_per_enemy
			local side = owner == config.OWNER_BLACK and "black" or "white"
			local player = require("match_state").player_for_color(state, side)
			player.resources.money = (player.resources.money or 0) + enemy_count * money_per
			state.scores.points[owner] = state.scores.points[owner] + enemy_count * points_per
		end,
	})
end


--- Immediate placement points plus a removal timer; stone leaves the board on expiry with no payout.
--- @param effect table
--- @return table
function M.self_destruct_timed(effect)
	return EffectSchema.build(effect, {
		type = "SELF_DESTRUCT_TIMED",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		kwargs_from_def = function(def)
			return {
				immediate_points = def.immediate_points
				or def.value
				or stone_params.self_destruct_immediate_points,
				delay_rounds = def.delay_rounds or stone_params.self_destruct_delay_rounds,
			}
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "immediate_points", "delay_rounds" })
			state.scores.points[owner] = state.scores.points[owner] + kwargs.immediate_points
			local row, col = helpers.placement_coords(state)
			if row and col then
				require("single_game.resolver.board_cell_timers").register(state, row, col, kwargs.delay_rounds)
			end
		end,
	})
end


--- End-of-turn payout from territory owner at the stone cell and that owner's total territory.
--- @param effect table
--- @return table
function M.territory_to_points(effect)
	return EffectSchema.build(effect, {
		type = "TERRITORY_TO_POINTS",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.end_of_turn,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, _owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			local row = kwargs.row
			local col = kwargs.col
			local cell = state.board[row] and state.board[row][col]
			if not cell or board.is_empty(cell) or cell.kind ~= "territory_to_points_stone" then
				return
			end
			local territory_mod = require("single_game.resolver.territory")
			local territory_grid, territory_value = territory_mod.territory_map_for_stone_payout(state, row, col)
			if not territory_grid then
				return
			end
			local recipient = territory_mod.owner_at_cell(territory_grid, row, col)
			if not recipient then
				return
			end
			local owner_color = recipient == config.OWNER_WHITE and config.STONE_WHITE or config.STONE_BLACK
			local total_territory = territory_mod.weighted_territory_points(territory_grid, owner_color, territory_value)
			local payout = territory_mod.territory_to_points_payout(total_territory)
			if payout <= 0 then
				return
			end
			state.scores.points[recipient] = state.scores.points[recipient] + payout
		end,
	})
end


--- Wall placement: +5 Points per 5 stones in the orthogonal connected group (wall included).
--- @param effect table
--- @return table
function M.wall_stone(effect)
	return EffectSchema.build(effect, {
		type = "WALL_STONE",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.wall_effect_priority,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "blocks" })
			local points = kwargs.blocks * stone_params.wall_points_per_block
			if points <= 0 then
				return
			end
			state.scores.points[owner] = state.scores.points[owner] + points
			local row, col = helpers.placement_coords(state)
			if not row or not col then
				return
			end
			local group = shape_patterns.group_connected(state.board, row, col)
			animations.add_animation("wall_stone_bounce")(state, {
				owner = owner,
				cells = group,
				bonus = points,
				anchor_row = row,
				anchor_col = col,
			})
		end,
	})
end


--- Line stone placement: points per full block of orthogonal connected group (line stone included).
--- @param effect table
--- @return table
function M.line_group_points(effect)
	return EffectSchema.build(effect, {
		type = "LINE_GROUP_POINTS",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.wall_effect_priority,
		kwargs_from_def = function(def)
			return { stone_kind = def.stone_kind or "line_stone" }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "stone_kind" })
			require("objects.effects_conditions.helpers.shared.connected_group_placement").apply_line(state, owner, kwargs.stone_kind)
		end,
	})
end


local ORTHOGONAL_OFFSETS = {
	{ -1, 0 },
	{ 1, 0 },
	{ 0, -1 },
	{ 0, 1 },
}

--- Marks one empty tile with a control-stone override owner; opposing claims on the same cell become contested.
--- @param tile table
--- @param owner "B"|"W"
--- @return nil
local function apply_control_override_to_tile(tile, owner)
	if tile.override_contested then
		return
	end
	if tile.override_owner == nil then
		tile.override_owner = owner
		return
	end
	if tile.override_owner == owner then
		return
	end
	tile.override_owner = nil
	tile.override_contested = true
end

--- Sets override ownership on orthogonal adjacent empty cells for one control stone.
--- @param state table
--- @param owner "B"|"W"
--- @param row integer
--- @param col integer
--- @return nil
local function apply_control_territory_override_at(state, owner, row, col)
	local tiles = state.territory_tiles
	if not tiles then
		return
	end
	local n = config.BOARD_SIZE
	for i = 1, #ORTHOGONAL_OFFSETS do
		local nr = row + ORTHOGONAL_OFFSETS[i][1]
		local nc = col + ORTHOGONAL_OFFSETS[i][2]
		if nr >= 1 and nr <= n and nc >= 1 and nc <= n and board.is_empty(state.board[nr][nc]) then
			apply_control_override_to_tile(tiles[nr][nc], owner)
		end
	end
end

--- Adds plus_mult when owner copper count on board already meets ``copper_threshold`` before this placement.
--- @param effect table
--- @return table
function M.copper_threshold_plus_mult(effect)
	return EffectSchema.build(effect, {
		type = "COPPER_THRESHOLD_PLUS_MULT",
		default_phase = scheduling.PHASE.mult,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		kwargs_from_def = function(def)
			return { value = def.value or stone_params.copper_threshold_plus_mult_bonus }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "value" })
			local row, col = helpers.placement_coords(state)
			if not row or not col then
				return
			end
			state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + kwargs.value
		end,
	})
end


--- Adds plus_mult from territory control streak at the placed cell (snapshot taken before occupancy clears streak).
--- @param effect table
--- @return table
function M.mult_control_streak(effect)
	return EffectSchema.build(effect, {
		type = "MULT_CONTROL_STREAK",
		default_phase = scheduling.PHASE.mult,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			local territory_control_rounds = require("single_game.resolver.helpers.territory_control_rounds")
			local streak = territory_control_rounds.placement_streak_snapshot(state)
			local delta = territory_control_rounds.plus_mult_delta_for_streak(streak, state, owner)
			if delta ~= 0 then
				state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + delta
			end
		end,
	})
end


--- Control stone override: orthogonal adjacent empty cells resolve to the stone owner after enclosure and influence.
--- @param effect table
--- @return table
function M.control_territory_override(effect)
	return EffectSchema.build(effect, {
		type = "CONTROL_TERRITORY_OVERRIDE",
		default_phase = scheduling.PHASE.territory,
		default_action = scheduling.ACTION.on_play,
		extra = { territory_step = effect.territory_step or "override" },
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			apply_control_territory_override_at(state, owner, kwargs.row, kwargs.col)
		end,
	})
end


--- Multiplies ``territory_value`` inside the owner enclosure containing this stone.
--- Nested opponent pockets are excluded. Nested same-owner pockets with another enclosure_stone are
--- excluded only when not an immediate inner pocket (so concentric stones stack on shared cells).
--- Occupied cells are skipped.
--- @param row integer
--- @param col integer
--- @param effect_def table
--- @return table
function M.enclosure_territory_multiply(row, col, effect_def)
	return EffectSchema.build(effect_def, {
		type = "ENCLOSURE_TERRITORY_MULTIPLY",
		default_phase = scheduling.PHASE.territory,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			local walls = state.enclosure_walls
			if not walls then
				walls = enclosure.extract_walls(state.board)
			end
			local stone_kind = state.board[row][col].kind
			local multiplier = effect_def.value or stone_params.enclosure_stone_multiplier
			local target_keys = resolve_enclosure_multiply_targets(
				walls,
				state.board,
				owner,
				row,
				col,
				stone_kind
			)
			if opponent_has_enclosure_stone(state.board, stone_kind, owner) then
				target_keys = filter_targets_by_region_owner(target_keys, state, owner)
			end
			if not next(target_keys) then
				return
			end
			state.territory_value = state.territory_value or {}
			for key in pairs(target_keys) do
				local tr = math.floor(key / 100)
				local tc = key % 100
				state.territory_value[tr] = state.territory_value[tr] or {}
				local cur = state.territory_value[tr][tc] or 1
				state.territory_value[tr][tc] = cur * multiplier
			end
		end,
	})
end


--- Records pre-placement territory ownership and totals for territory-to-multiplier payout on the placement turn.
--- @param effect table
--- @return table
function M.territory_to_multiplier_snapshot(effect)
	return EffectSchema.build(effect, {
		type = "TERRITORY_TO_MULTIPLIER_SNAPSHOT",
		default_phase = scheduling.PHASE.mult,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			local row, col = kwargs.row, kwargs.col
			if row == nil or col == nil then
				row, col = helpers.placement_coords(state)
			end
			require("objects.effects_conditions.helpers.shared.territory_to_multiplier").capture_snapshot(state, row, col)
		end,
	})
end


--- End-of-turn plus_mult from territory controlled by the owner of the stone cell.
--- @param effect table
--- @return table
function M.territory_to_multiplier(effect)
	return EffectSchema.build(effect, {
		type = "TERRITORY_TO_MULTIPLIER",
		default_phase = scheduling.PHASE.mult,
		default_action = scheduling.ACTION.end_of_turn,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col" })
			require("objects.effects_conditions.helpers.shared.territory_to_multiplier").apply_end_of_turn(state, kwargs.row, kwargs.col)
		end,
	})
end


--- Zeros the per-cell bank when an escalating points stone is first placed.
--- @param effect table
--- @return table
function M.escalating_points_bank_init(effect)
	return EffectSchema.build(effect, {
		type = "ESCALATING_POINTS_BANK_INIT",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			local row, col = kwargs.row, kwargs.col
			if row == nil or col == nil then
				row, col = helpers.placement_coords(state)
			end
			require("objects.effects_conditions.helpers.shared.escalating_points").init_bank(state, row, col)
		end,
	})
end


--- Each ``end_of_turn``, add ``eps_round_points`` to this cell bank and owner points.
--- @param effect table
--- @return table
function M.escalating_points_bank(effect)
	return EffectSchema.build(effect, {
		type = "ESCALATING_POINTS_BANK",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.end_of_turn,
		default_priority = stone_params.default_effect_priority,
		kwargs_from_def = function(def)
			return { round_points = def.value or stone_params.eps_round_points }
		end,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col", "round_points" })
			require("objects.effects_conditions.helpers.shared.escalating_points").apply_end_of_turn_bank(state, owner, kwargs.row, kwargs.col, kwargs.round_points)
		end,
	})
end


--- On removal: transfer banked points to an enemy captor with configured multiplier; clears the cell bank.
--- @param effect table
--- @return table
function M.escalating_points_capture_transfer(effect)
	return EffectSchema.build(effect, {
		type = "ESCALATING_POINTS_CAPTURE_TRANSFER",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_removed,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			require_kwargs.require_kwargs(kwargs, { "row", "col", "cell" })
			require("objects.effects_conditions.helpers.shared.escalating_points").apply_capture_transfer(state, kwargs.row, kwargs.col, kwargs.cell, kwargs.opts)
		end,
	})
end


--- Final-round placement payout; non-final rounds grant fallback points only.
--- @param effect table
--- @return table
function M.final_blow_placement(effect)
	return EffectSchema.build(effect, {
		type = "FINAL_BLOW_PLACEMENT",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			if helpers.is_final_round(state) then
				state.scores.points[owner] = state.scores.points[owner] + stone_params.final_blow_points
				state.scores.plus_mult[owner] = state.scores.plus_mult[owner] + stone_params.final_blow_plus_mult
				return
			end
			state.scores.points[owner] = state.scores.points[owner] + stone_params.final_blow_nonfinal_points
		end,
	})
end


--- Replays the placing owner's most recent retriggerable same-turn stone effect, or fallback points.
--- @param effect table
--- @return table
local NON_RETRIGGERABLE_STONE_IDS = { retrigger_stone = true }
local NON_RETRIGGERABLE_EFFECT_NAMES = {
	retrigger_prior_stone_effect = true,
	self_destruct_timed = true,
}

local function retrigger_is_stone(stone_id)
	return NON_RETRIGGERABLE_STONE_IDS[stone_id] ~= true
end

local function retrigger_is_effect(effect_name)
	return NON_RETRIGGERABLE_EFFECT_NAMES[effect_name] ~= true
end

local function retrigger_side_from_owner(owner)
	if owner == config.OWNER_WHITE then
		return "white"
	end
	return "black"
end

local function retrigger_is_board_replay(effect_def)
	local name = effect_def.effect_name
	return name == "wall_stone"
		or name == "diagonal_group_points"
		or name == "line_group_points"
		or name == "money_field_enclosure_payout"
		or name == "pattern_x_mult"
		or name == "pattern_plus_mult"
end

local function retrigger_find_prior(state, owner)
	local events = state.round_stone_effects
	if not events or #events == 0 then
		return nil
	end
	for i = #events - 1, 1, -1 do
		local event = events[i]
		if event.owner == owner and retrigger_is_stone(event.stone_type) then
			return event
		end
	end
	return nil
end

local function retrigger_replay_def(state, owner, event, effect_def)
	if not retrigger_is_effect(effect_def.effect_name) then
		return
	end
	local row = event.row
	local col = event.col
	local prev_move = state.last_opponent_move
	local side = retrigger_side_from_owner(owner)
	state.last_opponent_move = {
		stone_id = event.stone_type,
		row = row,
		col = col,
		actor = side,
	}
	local resolved = M.resolve(effect_def)
	if resolved and resolved.apply then
		local scoring_phases = require("single_game.resolver.scoring_phases")
		if not retrigger_is_board_replay(effect_def)
			and scoring_phases.is_board_territory_effect(effect_def) then
		else
			require("objects.effects_conditions.run").apply_effect(resolved, state, owner)
		end
	end
	state.last_opponent_move = prev_move
end

local function retrigger_replay_event(state, owner, event)
	state._retrigger_replay_depth = (state._retrigger_replay_depth or 0) + 1
	if state._retrigger_replay_depth > 1 then
		state._retrigger_replay_depth = state._retrigger_replay_depth - 1
		return
	end
	local replayed = {}
	for i = 1, #(event.effects or {}) do
		local effect_def = event.effects[i]
		retrigger_replay_def(state, owner, event, effect_def)
		if retrigger_is_board_replay(effect_def) then
			replayed[effect_def.effect_name] = true
		end
	end
	local content = require("content")
	local stone_def = content.get_stone(event.stone_type)
	if stone_def and stone_def.effects then
		for i = 1, #stone_def.effects do
			local effect_def = stone_def.effects[i]
			if retrigger_is_board_replay(effect_def) and not replayed[effect_def.effect_name] then
				retrigger_replay_def(state, owner, event, effect_def)
			end
		end
	end
	state._retrigger_replay_depth = state._retrigger_replay_depth - 1
end

local function retrigger_apply_or_fallback(state, owner)
	if state._retrigger_replay_depth and state._retrigger_replay_depth > 0 then
		return
	end
	local prior = retrigger_find_prior(state, owner)
	if not prior then
		state.scores.points[owner] = state.scores.points[owner] + stone_params.retrigger_fallback_points
		return
	end
	retrigger_replay_event(state, owner, prior)
end

function M.retrigger_prior_stone_effect(effect)
	return EffectSchema.build(effect, {
		type = "RETRIGGER_PRIOR_STONE_EFFECT",
		default_phase = scheduling.PHASE.points,
		default_action = scheduling.ACTION.on_play,
		default_priority = stone_params.default_effect_priority,
		apply = function(state, owner, kwargs)
			retrigger_apply_or_fallback(state, owner)
		end,
	})
end


--- Double corner nearby territory effect: corner tower adds ``1`` to ``territory_value`` on every cell in the
--- board-aligned ``3├ù3`` block anchored at that corner (excluding the tower cell). Stacks with prior cell values.
--- @param row integer
--- @param col integer
--- @param effect_def table
--- @return table
function M.double_corner_nearby_territory(row, col, effect_def)
	return EffectSchema.build(effect_def, {
		type = "DOUBLE_CORNER_NEARBY_TERRITORY",
		default_phase = scheduling.PHASE.territory,
		default_action = scheduling.ACTION.on_play,
		apply = function(state, owner, kwargs)
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
	})
end



local BOARD_EFFECT_BUILDERS = {
	double_corner_nearby_territory = true,
	enclosure_territory_multiply = true,
}

local BOARD_COORD_EFFECT_NAMES = {
	control_territory_override = true,
	territory_to_points = true,
	territory_to_multiplier = true,
	territory_to_multiplier_snapshot = true,
	tax_enclosure_enemies = true,
	escalating_points_bank = true,
	escalating_points_bank_init = true,
	escalating_money_tracker = true,
}

local BOARD_SCAN_ONLY = {
	distance_bonus = true,
	enclosure_territory_multiply = true,
	double_corner_nearby_territory = true,
}

--- Generic effect resolver: dispatch by effect_name.
function M.resolve(effect_def)
	if not effect_def or not effect_def.effect_name then
		return nil
	end
	if BOARD_SCAN_ONLY[effect_def.effect_name] then
		if effect_def.effect_name == "enclosure_territory_multiply"
			or effect_def.effect_name == "double_corner_nearby_territory" then
			return nil
		end
	end
	local builder = M[effect_def.effect_name]
	if not builder then
		return nil
	end
	return builder(effect_def)
end

--- Resolve a board-scan effect that needs placement coordinates at resolve time.
function M.resolve_at_board(row, col, effect_def)
	if not effect_def or not effect_def.effect_name then
		return nil
	end
	if effect_def.effect_name == "enclosure_territory_multiply" then
		return M.enclosure_territory_multiply(row, col, effect_def)
	end
	if effect_def.effect_name == "double_corner_nearby_territory" then
		return M.double_corner_nearby_territory(row, col, effect_def)
	end
	local builder = M[effect_def.effect_name]
	if not builder then
		return nil
	end
	return builder(effect_def)
end

--- Wrap board-scan apply with default owner and optional row/col kwargs.
function M.wrap_board_scan(resolved, owner, row, col)
	if not resolved or not resolved.apply then
		return resolved
	end
	local base_apply = resolved.apply
	local needs_coords = BOARD_COORD_EFFECT_NAMES[resolved.effect_name]
	resolved.apply = function(state, effect_owner, kwargs)
		local merged = kwargs or {}
		if needs_coords then
			merged = EffectSchema.merge_kwargs(merged, { row = row, col = col })
		end
		base_apply(state, effect_owner or owner, merged)
	end
	return resolved
end

--- Board-scoped stone effects for distance/territory/end_of_turn board scans.
function M.resolve_board_stone(stone_cell, row, col, state, active_action, active_phase, territory_step)
	local scoring_phases = require("single_game.resolver.scoring_phases")
	local content = require("content")
	local stone_ref = stone_cell.level and { def_id = stone_cell.kind, level = stone_cell.level } or stone_cell.kind
	local stone_def = content.resolve_stone(stone_ref)
	local key = helpers.stone_key(row, col)
	local n = config.BOARD_SIZE
	local out = {}
	local effect_defs = {}
	local owner = stone_cell.color == config.STONE_BLACK and config.OWNER_BLACK or config.OWNER_WHITE
	local action = scheduling.normalize_action(active_action or state._resolve_action) or scheduling.ACTION.on_play

	if stone_def and stone_def.effects then
		for i = 1, #stone_def.effects do
			effect_defs[#effect_defs + 1] = stone_def.effects[i]
		end
	end

	for _, effect_def in ipairs(effect_defs) do
		if scoring_phases.skips_board_scan(effect_def) then
		elseif not scoring_phases.matches(effect_def, action, active_phase, territory_step) then
		elseif effect_def.effect_name == "distance_bonus" then
			local resolved = M.resolve(effect_def)
			if resolved then
				resolved.action = action
				resolved.phase = active_phase
				resolved.apply = function(current_state, effect_owner, kwargs)
					require_kwargs.require_kwargs(
						EffectSchema.merge_kwargs(kwargs, {
							stone_def = stone_def,
							stone_key = key,
							board_size = n,
							value = effect_def.value,
						}),
						{ "stone_def", "stone_key", "board_size", "value" }
					)
					helpers.apply_distance_bonus_for_stone(
						stone_def,
						current_state,
						key,
						n,
						effect_def.value
					)
				end
				out[#out + 1] = resolved
			end
		elseif effect_def.effect_name == "enclosure_territory_multiply"
			or effect_def.effect_name == "double_corner_nearby_territory" then
			local resolved = M.resolve_at_board(row, col, effect_def)
			if resolved then
				resolved.action = action
				resolved.phase = active_phase
				out[#out + 1] = M.wrap_board_scan(resolved, owner, row, col)
			end
		else
			local resolved = M.resolve(effect_def)
			if resolved and resolved.apply then
				resolved.action = action
				resolved.phase = active_phase
				out[#out + 1] = M.wrap_board_scan(resolved, owner, row, col)
			end
		end
	end

	return out
end

--- Runs stone-declared on_removed effects for a cell being cleared from the board.
function M.apply_on_removed_effects(state, row, col, cell, opts)
	if board.is_empty(cell) then
		return
	end
	local content = require("content")
	local stone_ref = cell.level and { def_id = cell.kind, level = cell.level } or cell.kind
	local stone_def = content.resolve_stone(stone_ref)
	if not stone_def or not stone_def.effects then
		return
	end
	for i = 1, #stone_def.effects do
		local effect_def = stone_def.effects[i]
		local removal_action = effect_def.action or effect_def.when
		if removal_action == scheduling.ACTION.on_removed or removal_action == "on_removed" then
			local resolved = M.resolve(effect_def)
			if resolved and resolved.apply then
				resolved.apply(state, nil, { row = row, col = col, cell = cell, opts = opts })
			end
		end
	end
end

--- Resolves card definition effects.
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
