--- Placement capture for ``capture_stone``: zero-liberty enemy removal and mixed-surround cooldown grid.
--- @module single_game.resolver.capture_stone

local board = require("board")
local config = require("config")
local rules = require("rules")
local stone_params = require("objects.parameters.stones")

local M = {}

local STREAM_KEY = "capture_stone"

--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param state table
--- @return nil
function M.ensure_state(state)
	state.capture_cooldown_cells = state.capture_cooldown_cells or {}
	state.former_capture_cooldown_cells = state.former_capture_cooldown_cells or {}
	state.blocked_cells = state.blocked_cells or {}
end

--- @param stone_def table|nil
--- @return boolean
function M.stone_def_has_effect(stone_def)
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
local function stone_empty_neighbor_count(b, row, col)
	local count = 0
	for nr, nc in rules.each_neighbor(row, col) do
		if board.is_empty(b[nr][nc]) then
			count = count + 1
		end
	end
	return count
end

--- @param b table
--- @param opponent_color integer
--- @return table
local function enemy_stones_at_zero_liberties(b, opponent_color)
	local n = config.BOARD_SIZE
	local out = {}
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) and cell.color == opponent_color then
				if stone_empty_neighbor_count(b, r, c) == 0 then
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
local function pick_candidate_index(state, stream_key, count)
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

--- @param b table
--- @param row integer
--- @param col integer
--- @param captor_chain_color integer
--- @return boolean
local function mixed_surround_at_cell(b, row, col, captor_chain_color)
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
local function set_capture_cooldown(state, row, col, captor_side)
	M.ensure_state(state)
	local key = cell_key(row, col)
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
function M.is_active_capture_cooldown_key(state, key)
	M.ensure_state(state)
	local entry = state.capture_cooldown_cells[key]
	return entry ~= nil and (entry.remaining or 0) > 0
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return boolean
function M.had_former_capture_cooldown(state, row, col)
	M.ensure_state(state)
	return state.former_capture_cooldown_cells[cell_key(row, col)] == true
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return boolean
function M.is_cell_blocked_for_actor(state, row, col, actor, stone_id)
	if stone_id == "kamikaze_stone" then
		return false
	end
	M.ensure_state(state)
	local key = cell_key(row, col)
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
function M.is_cell_on_capture_cooldown(state, row, col)
	M.ensure_state(state)
	local key = cell_key(row, col)
	local entry = state.capture_cooldown_cells[key]
	return entry ~= nil and (entry.remaining or 0) > 0
end

--- @param state table
--- @return nil
function M.tick_capture_cooldowns(state)
	M.ensure_state(state)
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
--- @param state table
--- @param actor string
--- @param captor_chain_color integer
--- @return table
--- @return integer
--- @return table|nil
function M.apply_extra_capture(b, state, actor, captor_chain_color)
	local opponent = board.opponent_stone(captor_chain_color)
	local candidates = enemy_stones_at_zero_liberties(b, opponent)
	if #candidates == 0 then
		return b, 0, nil
	end
	local pick = pick_candidate_index(state, STREAM_KEY, #candidates)
	local target = candidates[pick]
	b[target.row][target.col] = config.STONE_NONE
	if mixed_surround_at_cell(b, target.row, target.col, captor_chain_color) then
		set_capture_cooldown(state, target.row, target.col, actor)
	end
	return b, 1, target
end

return M
