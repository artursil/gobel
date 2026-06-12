--- Opponent-only placement blocks from blockade stones (per-cell duration, max overlap).
---
--- **Board-zone exception:** blockade durations are stored on empty adjacent cells in
--- ``state.placement_blocks`` / ``state.blocked_cells``, not on the blockade stone cell.
--- Cell-owned tick fields (``survival_rounds_remaining``, ``immunity_remaining``) use
--- ``effect_tick_lifecycle`` instead.
--- @module resolver.blocked_cells

local board = require("board")
local config = require("config")
local rules = require("rules")
local stone_params = require("objects.parameters.stones")

local M = {}

--- @param row integer
--- @param col integer
--- @return string
local function cell_key(row, col)
	return row .. ":" .. col
end

--- @param state table
--- @return nil
function M.ensure(state)
	if state.placement_blocks then
		return
	end
	state.placement_blocks = {}
	state.blocked_cells = state.blocked_cells or {}
	state._blocked_cells_sync = state._blocked_cells_sync or {}
	setmetatable(state.blocked_cells, {
		__index = function(t, key)
			M.bootstrap_from_board_if_needed(state)
			return rawget(t, key)
		end,
	})
end

--- @param state table
--- @param key string
--- @return nil
local function sync_side_blocks_from_zone(state, key)
	local entry = state.placement_blocks[key]
	if not entry then
		state._blocked_cells_sync[key] = nil
		return
	end
	local zone = state.blocked_cells[key] or 0
	local prev_zone = state._blocked_cells_sync[key]
	if prev_zone == nil then
		state._blocked_cells_sync[key] = zone
		return
	end
	if zone >= prev_zone then
		state._blocked_cells_sync[key] = zone
		return
	end
	local delta = prev_zone - zone
	entry.white = math.max(0, (entry.white or 0) - delta)
	entry.black = math.max(0, (entry.black or 0) - delta)
	state._blocked_cells_sync[key] = zone
	if (entry.white or 0) <= 0 and (entry.black or 0) <= 0 then
		state.placement_blocks[key] = nil
		state.blocked_cells[key] = nil
		state._blocked_cells_sync[key] = nil
	end
end

--- @param state table
--- @param key string
--- @return nil
local function sync_zone_marker(state, key)
	local entry = state.placement_blocks[key]
	if not entry then
		state.blocked_cells[key] = nil
		state._blocked_cells_sync[key] = nil
		return
	end
	local zone = math.max(entry.white or 0, entry.black or 0)
	if zone <= 0 then
		state.placement_blocks[key] = nil
		state.blocked_cells[key] = nil
		state._blocked_cells_sync[key] = nil
		return
	end
	state.blocked_cells[key] = zone
	state._blocked_cells_sync[key] = zone
end

--- @param state table
--- @param key string
--- @return nil
local function sync_entry(state, key)
	sync_zone_marker(state, key)
	sync_side_blocks_from_zone(state, key)
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param blocked_side "black"|"white"
--- @param duration integer
--- @return nil
function M.add_block_for_side(state, row, col, blocked_side, duration)
	if duration <= 0 then
		return
	end
	M.ensure(state)
	local key = cell_key(row, col)
	local entry = state.placement_blocks[key] or { white = 0, black = 0 }
	entry[blocked_side] = math.max(entry[blocked_side] or 0, duration)
	state.placement_blocks[key] = entry
	sync_entry(state, key)
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param actor "black"|"white"
--- @return nil
function M.register_adjacent_from_blockade(state, row, col, actor)
	local b = state.board
	if not b then
		return
	end
	local blocked_side = actor == "black" and "white" or "black"
	local duration = stone_params.blockade_duration_rounds
	for nr, nc in rules.each_neighbor(row, col) do
		if board.is_empty(b[nr][nc]) then
			M.add_block_for_side(state, nr, nc, blocked_side, duration)
		end
	end
end

--- @param state table
--- @return nil
function M.bootstrap_from_board_if_needed(state)
	if state._blockade_board_bootstrapped then
		return
	end
	local b = state.board
	if not b then
		return
	end
	M.ensure(state)
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) and cell.kind == "blockade_stone" then
				local actor = cell.color == config.STONE_BLACK and "black" or "white"
				M.register_adjacent_from_blockade(state, r, c, actor)
			end
		end
	end
	state._blockade_board_bootstrapped = true
end

--- @param state table
--- @param row integer
--- @param col integer
--- @param actor "black"|"white"
--- @return boolean
function M.is_blocked_for_actor(state, row, col, actor)
	M.ensure(state)
	M.bootstrap_from_board_if_needed(state)
	local key = cell_key(row, col)
	sync_side_blocks_from_zone(state, key)
	local entry = state.placement_blocks[key]
	if not entry then
		return false
	end
	local remaining = entry[actor] or 0
	return remaining > 0
end

--- @param state table
--- @return nil
function M.tick(state)
	M.ensure(state)
	M.bootstrap_from_board_if_needed(state)
	local next_blocks = {}
	for key, entry in pairs(state.placement_blocks) do
		local white = math.max(0, (entry.white or 0) - 1)
		local black = math.max(0, (entry.black or 0) - 1)
		if white > 0 or black > 0 then
			next_blocks[key] = { white = white, black = black }
		end
	end
	state.placement_blocks = next_blocks
	state._blocked_cells_sync = {}
	for key in pairs(state.blocked_cells) do
		if type(key) == "string" then
			state.blocked_cells[key] = nil
		end
	end
	for key in pairs(state.placement_blocks) do
		sync_entry(state, key)
	end
end

return M
