--- Territory grid: influence map, region ownership, and per-cell stone colors for empty cells.
--- @module resolver.territory

local board = require("board")
local config = require("config")
local influence_map = require("resolver.influence")
local enclosure = require("resolver.enclosure")

local M = {}

--- @return table
local function new_tile()
	return {
		influence = { A = 0, B = 0 },
		region_id = nil,
		override_owner = nil,
		owner = nil,
	}
end

--- @param b table
--- @return table
local function init_tiles(b)
	local n = config.BOARD_SIZE
	local tiles = {}
	for r = 1, n do
		tiles[r] = {}
		for c = 1, n do
			tiles[r][c] = new_tile()
		end
	end
	return tiles
end

--- @param owner string|nil
--- @return any
local function owner_to_stone(owner)
	if owner == "A" then
		return config.STONE_BLACK
	end
	if owner == "B" then
		return config.STONE_WHITE
	end
	return config.STONE_NONE
end

--- Writes `owner` on each empty tile; returns a board-sized grid of stone colors.
--- @param tiles table
--- @param regions table|nil
--- @param b table
--- @param print_debug boolean
--- @return table
local function finish_resolve_owners(tiles, regions, b, print_debug)
	local n = config.BOARD_SIZE
	local out = {}
	for r = 1, n do
		out[r] = {}
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				out[r][c] = cell.color
			else
				local t = tiles[r][c]
				local own = nil
				if t.override_owner then
					own = t.override_owner
					if print_debug then
						print("[Territory] override at", r, c, "->", own)
					end
				elseif t.region_id and regions and regions[t.region_id] and regions[t.region_id].owner then
					own = regions[t.region_id].owner
				else
					local ia, ib = t.influence.A, t.influence.B
					if ia > ib then
						own = "A"
					elseif ib > ia then
						own = "B"
					else
						own = nil
					end
				end
				t.owner = own
				out[r][c] = owner_to_stone(own)
			end
		end
	end
	return out
end

--- @param territory_grid table
--- @return integer, integer
local function count_controlled(territory_grid)
	local n = config.BOARD_SIZE
	local black, white = 0, 0
	for r = 1, n do
		for c = 1, n do
			if territory_grid[r][c] == config.STONE_BLACK then
				black = black + 1
			elseif territory_grid[r][c] == config.STONE_WHITE then
				white = white + 1
			end
		end
	end
	return black, white
end

--- @param regions table
--- @return integer
local function region_count(regions)
	local count = 0
	for _ in pairs(regions) do
		count = count + 1
	end
	return count
end

--- Builds `territory_tiles` and `regions` (influence + enclosure). Call before territory-phase effects.
--- @param state table
--- @return nil
function M.begin_assignment(state)
	local b = state.board
	local tiles = init_tiles(b)
	influence_map.build_influence_map(b, state.territory_mode or "regional", tiles)
	state.territory_tiles = tiles
	state.regions = enclosure.detect_regions_and_ownership(b, tiles)
	print("[Territory] region count", region_count(state.regions))
end

--- Sets `state.territory` and updates `scores.territory` from controlled cell counts.
--- @param state table
--- @return nil
function M.finish_assignment(state)
	local b = state.board
	local tiles = state.territory_tiles
	local regions = state.regions
	if not tiles then
		return
	end
	state.territory = finish_resolve_owners(tiles, regions, b, true)
	local black_c, white_c = count_controlled(state.territory)
	local tn = state.turn_number or 1
	state.scores.territory.A = tn * black_c
	state.scores.territory.B = tn * white_c
end

--- Standalone helper: no `state` mutation. Returns a territory color grid.
--- @param b table
--- @param territory_mode string|nil
--- @return table
function M.compute_from_board(b, territory_mode)
	local tiles = init_tiles(b)
	influence_map.build_influence_map(b, territory_mode or "regional", tiles)
	local regions = enclosure.detect_regions_and_ownership(b, tiles)
	return finish_resolve_owners(tiles, regions, b, false)
end

return M
