--- Shared helpers for ``objects.effects`` (Echo copy-right, board stone distance layout). Kept separate so ``objects.effects`` stays effect builders and dispatch only.
--- @module objects.effects_conditions.helpers.shared.effects_helpers

local board = require("board")
local config = require("config")
local energy = require("energy")
local queries = require("single_game.resolver.helpers.state_queries")
local rules = require("rules")
local stone_params = require("objects.parameters.stones")

local H = {}

local CAPTURE_STONE_RNG_STREAM = "capture_stone"

--- Side whose turn just ended for the active ``end_of_turn`` resolve.
--- Uses explicit resolver hook when set; otherwise infers from ``to_play`` for round-advance test paths.
--- @param state table
--- @return string|nil ``config.OWNER_BLACK`` | ``config.OWNER_WHITE``
function H.active_end_of_turn_owner(state)
	if state._end_of_turn_owner == config.OWNER_BLACK or state._end_of_turn_owner == config.OWNER_WHITE then
		return state._end_of_turn_owner
	end
	local to_play = state.to_play
	if to_play == "white" then
		return config.OWNER_BLACK
	end
	if to_play == "black" then
		return config.OWNER_WHITE
	end
	return nil
end

local copy_right_shared = require("objects.effects_conditions.helpers.shared.copy_right")

function H.resolve_blueprint_target(state, owner, source_slot_index)
	return copy_right_shared.resolve_blueprint_target(state, owner, source_slot_index)
end

function H.normalize_stance_owner(owner)
	return copy_right_shared.normalize_stance_owner(owner)
end

function H.get_copy_right_target(state)
	return copy_right_shared.get_copy_right_target(state)
end

function H.get_target_effects(state, target_def, resolve_effect)
	return copy_right_shared.get_target_effects(state, target_def, resolve_effect)
end

function H.with_resolution_for_copied_stance_target(state, target, fn)
	return copy_right_shared.with_resolution_for_copied_stance_target(state, target, fn)
end

function H.apply_copied_effect(state, target, target_owner, resolved_effects)
	return copy_right_shared.apply_copied_effect(state, target, target_owner, resolved_effects)
end

--- Stone key generator for distance modifier indexing.
--- @param row integer
--- @param col integer
--- @return integer
function H.stone_key(row, col)
	return row * 100 + col
end

--- @param row integer
--- @param col integer
--- @return string
function H.stone_cell_key(row, col)
	return row .. ":" .. col
end

--- Reads per-cell stored value used by escalating bank stones.
--- @param state table
--- @param row integer
--- @param col integer
--- @return number|nil
function H.stone_stored_value(state, row, col)
	local cell = state.board and state.board[row] and state.board[row][col]
	if type(cell) == "table" and cell.stored_value ~= nil then
		return cell.stored_value
	end
	return nil
end

--- Writes per-cell stored value used by escalating bank stones.
--- @param state table
--- @param row integer
--- @param col integer
--- @param value number
--- @return nil
function H.set_stone_stored_value(state, row, col, value)
	local row_cells = state.board and state.board[row]
	local cell = row_cells and row_cells[col]
	if type(cell) == "table" then
		cell.stored_value = value
	end
end

function H.gain_player_energy(state, owner, amount)
	local side = owner == config.OWNER_WHITE and "white" or "black"
	local player = require("match_state").player_for_color(state, side)
	if not player then
		return
	end
	energy.gain(player, amount)
end

--- Whether the active match is on its final round (explicit test flag or round limit).
--- @param state table
--- @return boolean
function H.is_final_round(state)
	if state.is_final_round == true then
		return true
	end
	local round_number = state.round_number or 1
	local max_rounds = state.max_rounds or state.round_limit
	if type(max_rounds) == "number" and max_rounds > 0 then
		return round_number >= max_rounds
	end
	return false
end

--- Adds permanent per-cell point bonus for board stone scoring.
--- @param state table
--- @param row integer
--- @param col integer
--- @param points integer
--- @return nil
function H.add_cell_points_bonus(state, row, col, points)
	if points == 0 then
		return
	end
	state.board_stone_modifiers = state.board_stone_modifiers or {}
	local key = row .. ":" .. col
	state.board_stone_modifiers[key] = state.board_stone_modifiers[key] or { points_bonus = 0 }
	state.board_stone_modifiers[key].points_bonus = state.board_stone_modifiers[key].points_bonus + points
end

--- @param row integer
--- @param col integer
--- @return string
function H.capture_cell_key(row, col)
	return row .. ":" .. col
end

--- @param state table
--- @return nil
function H.ensure_capture_cooldown_state(state)
	state.capture_cooldown_cells = state.capture_cooldown_cells or {}
	state.former_capture_cooldown_cells = state.former_capture_cooldown_cells or {}
	state.blocked_cells = state.blocked_cells or {}
end

--- @param stone_def table|nil
--- @return boolean
function H.stone_def_has_capture_zero_liberty_effect(stone_def)
	if not stone_def or not stone_def.effects then
		return false
	end
	for i = 1, #stone_def.effects do
		if stone_def.effects[i].effect_name == "capture_zero_liberty_enemy" then
			return true
		end
	end
	return false
end

--- @param b table
--- @param row integer
--- @param col integer
--- @return integer
function H.stone_empty_neighbor_count(b, row, col)
	local count = 0
	for nr, nc in rules.each_neighbor(row, col) do
		if board.is_empty(b[nr][nc]) then
			count = count + 1
		end
	end
	return count
end

--- @param b table
--- @param row integer
--- @param col integer
--- @param captor_chain_color integer
--- @return boolean
function H.mixed_surround_at_cell(b, row, col, captor_chain_color)
	for nr, nc in rules.each_neighbor(row, col) do
		local cell = b[nr][nc]
		if not board.is_empty(cell) and cell.color ~= captor_chain_color then
			return true
		end
	end
	return false
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param captor_side string
--- @return nil
function H.set_capture_cooldown(state, row, col, captor_side)
	H.ensure_capture_cooldown_state(state)
	local key = H.capture_cell_key(row, col)
	local remaining = stone_params.capture_cooldown_rounds
	state.capture_cooldown_cells[key] = {
		remaining = remaining,
		captor = captor_side,
	}
	state.blocked_cells[key] = remaining
	state.former_capture_cooldown_cells[key] = true
	state._capture_cooldown_set_turn = state.turn_number or 1
end

--- @param state table
--- @param key string
--- @return boolean
function H.is_active_capture_cooldown_key(state, key)
	H.ensure_capture_cooldown_state(state)
	local entry = state.capture_cooldown_cells[key]
	return entry ~= nil and (entry.remaining or 0) > 0
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return boolean
function H.had_former_capture_cooldown(state, row, col)
	H.ensure_capture_cooldown_state(state)
	return state.former_capture_cooldown_cells[H.capture_cell_key(row, col)] == true
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param actor string
--- @param stone_id string|nil
--- @return boolean
function H.is_cell_blocked_for_capture_cooldown(state, row, col, actor, stone_id)
	if stone_id == "kamikaze_stone" then
		return false
	end
	H.ensure_capture_cooldown_state(state)
	local key = H.capture_cell_key(row, col)
	local entry = state.capture_cooldown_cells[key]
	if not entry or (entry.remaining or 0) <= 0 then
		return false
	end
	if entry.captor == actor then
		return false
	end
	return true
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return boolean
function H.is_cell_on_capture_cooldown(state, row, col)
	H.ensure_capture_cooldown_state(state)
	local key = H.capture_cell_key(row, col)
	local entry = state.capture_cooldown_cells[key]
	return entry ~= nil and (entry.remaining or 0) > 0
end

--- @param state table
--- @return nil
function H.sync_capture_cooldown_blocked_cells(state)
	H.ensure_capture_cooldown_state(state)
	for key, entry in pairs(state.capture_cooldown_cells) do
		if entry.remaining > 0 then
			state.blocked_cells[key] = entry.remaining
		else
			state.blocked_cells[key] = nil
		end
	end
end

--- @param state table
--- @return nil
function H.tick_capture_cooldowns(state)
	H.ensure_capture_cooldown_state(state)
	if (state.turn_number or 1) <= (state._capture_cooldown_set_turn or 0) then
		return
	end
	for key, entry in pairs(state.capture_cooldown_cells) do
		entry.remaining = entry.remaining - 1
		if entry.remaining <= 0 then
			state.capture_cooldown_cells[key] = nil
			state.blocked_cells[key] = nil
		else
			state.blocked_cells[key] = entry.remaining
		end
	end
end

--- @param b table
--- @param opponent_color integer
--- @return table
function H.enemy_stones_at_zero_empty_neighbors(b, opponent_color)
	local n = config.BOARD_SIZE
	local out = {}
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) and cell.color == opponent_color then
				if H.stone_empty_neighbor_count(b, r, c) == 0 then
					out[#out + 1] = { row = r, col = c }
				end
			end
		end
	end
	table.sort(out, function(a, b_entry)
		if a.row ~= b_entry.row then
			return a.row < b_entry.row
		end
		return a.col < b_entry.col
	end)
	return out
end

--- @param state table
--- @param stream_key string
--- @param count integer
--- @return integer
function H.pick_capture_candidate_index(state, stream_key, count)
	if count <= 0 then
		return 0
	end
	if count == 1 then
		return 1
	end
	if state.test_rng_streams and state.test_rng_streams[stream_key] then
		return state.test_rng_streams[stream_key](count)
	end
	local rng_mod = require("single_run.rng")
	state.rng_streams = state.rng_streams or {}
	local run_state = {
		seed = {
			base_seed = state.rng.seed,
			streams = state.rng_streams,
		},
	}
	return rng_mod.next_int(run_state, stream_key, count)
end

--- @param state table
--- @param old_board table
--- @param new_board table
--- @param actor string
--- @param captor_chain_color integer
--- @return nil
function H.apply_capture_cooldowns_for_removals(state, old_board, new_board, actor, captor_chain_color)
	H.ensure_capture_cooldown_state(state)
	local opponent = board.opponent_stone(captor_chain_color)
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local old_cell = old_board[r][c]
			local new_cell = new_board[r][c]
			if not board.is_empty(old_cell) and old_cell.color == opponent and board.is_empty(new_cell) then
				if H.mixed_surround_at_cell(new_board, r, c, captor_chain_color) then
					H.set_capture_cooldown(state, r, c, actor)
				end
			end
		end
	end
end

--- @param b table
--- @param state table
--- @param actor string
--- @param captor_chain_color integer
--- @return table
--- @return integer
function H.apply_zero_liberty_enemy_capture(b, state, actor, captor_chain_color)
	local opponent = board.opponent_stone(captor_chain_color)
	local candidates = H.enemy_stones_at_zero_empty_neighbors(b, opponent)
	if #candidates == 0 then
		return b, 0
	end
	local pick = H.pick_capture_candidate_index(state, CAPTURE_STONE_RNG_STREAM, #candidates)
	local target = candidates[pick]
	b[target.row][target.col] = config.STONE_NONE
	if H.mixed_surround_at_cell(b, target.row, target.col, captor_chain_color) then
		H.set_capture_cooldown(state, target.row, target.col, actor)
	end
	return b, 1
end

--- Apply distance bonus for a stone across all tiles.
--- @param stone_def table
--- @param current_state table
--- @param key integer
--- @param n integer
--- @param distance_bonus_value integer
--- @return nil
function H.apply_distance_bonus_for_stone(stone_def, current_state, key, n, distance_bonus_value)
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

--- Row/col of the stone just placed (from ``last_opponent_move``).
--- @param state table
--- @return integer|nil, integer|nil
function H.placement_coords(state)
	local move = state.last_opponent_move
	if move and move.row and move.col then
		return move.row, move.col
	end
	return nil, nil
end

return H
