--- Territory grid: enclosure/override precedence + per-tile closest-stone Manhattan assignment.
--- @module resolver.territory

local board = require("board")
local config = require("config")
local enclosure = require("resolver.enclosure")
local effect_manager = require("resolver.effect_manager")

local M = {}

--- @param r1 integer
--- @param c1 integer
--- @param r2 integer
--- @param c2 integer
--- @return integer
local function manhattan(r1, c1, r2, c2)
	return math.abs(r1 - r2) + math.abs(c1 - c2)
end

--- @param color any
--- @return "A"|"B"|nil
local function color_to_owner(color)
	if color == config.STONE_BLACK then
		return "A"
	end
	if color == config.STONE_WHITE then
		return "B"
	end
	return nil
end


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
local function finish_resolve_owners(tiles, regions, b, state, territory_mode, print_debug)
	local n = config.BOARD_SIZE
	local out = {}

	local function collect_stones()
		local A_stones, B_stones = {}, {}
		for r = 1, n do
			for c = 1, n do
				local cell = b[r][c]
				if not board.is_empty(cell) then
					local owner = color_to_owner(cell.color)
					if owner == "A" or owner == "B" then
						local entry = {
							row = r,
							col = c,
							key = r * 100 + c,
							color = cell.color,
							kind = cell.kind,
						}

						if owner == "A" then
							A_stones[#A_stones + 1] = entry
						else
							B_stones[#B_stones + 1] = entry
						end
					end
				end
			end
		end
		return A_stones, B_stones
	end

	local A_stones, B_stones = collect_stones()

	local function effective_distance(tile_r, tile_c, stones)
		local best = math.huge
		local distance_modifiers = state.distance_modifiers
		local get_bonus = distance_modifiers and distance_modifiers.get_bonus
		for i = 1, #stones do
			local stone = stones[i]
			local bonus = 0
			if type(get_bonus) == "function" then
				bonus = get_bonus(distance_modifiers, stone.key, tile_r, tile_c) or 0
			end
			local d = manhattan(tile_r, tile_c, stone.row, stone.col) - bonus
			if d < best then
				best = d
			end
		end
		return best
	end

	local function compute_tile_owner(tile_r, tile_c)
		local da = effective_distance(tile_r, tile_c, A_stones)
		local db = effective_distance(tile_r, tile_c, B_stones)
		if da < db then
			return "A"
		elseif db < da then
			return "B"
		end
		return nil
	end

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
					own = compute_tile_owner(r, c)
				end
				t.owner = own
				out[r][c] = owner_to_stone(own)
			end
		end
	end
	return out
end

--- @param territory_grid table
--- @param b table
--- @param state table
--- @return integer, integer
local function count_controlled(territory_grid, b, state)
	local n = config.BOARD_SIZE
	local black, white = 0, 0
	local territory_value = state.territory_value or {}
	for r = 1, n do
		for c = 1, n do
			if board.is_empty(b[r][c]) then
				local value = (territory_value[r] and territory_value[r][c]) or 1
				if territory_grid[r][c] == config.STONE_BLACK then
					black = black + value
				elseif territory_grid[r][c] == config.STONE_WHITE then
					white = white + value
				end
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
	local territory_mode = state.territory_mode or "regional"
	state.territory = finish_resolve_owners(tiles, regions, b, state, territory_mode, true)
	local black_c, white_c = count_controlled(state.territory, b, state)
	state.scores.territory.A = black_c
	state.scores.territory.B = white_c
end

--- Standalone helper: no `state` mutation. Returns a territory color grid.
--- @param b table
--- @param territory_mode string|nil
--- @return table
function M.compute_from_board(b, territory_mode)
	local tiles = init_tiles(b)
	local regions = enclosure.detect_regions_and_ownership(b, tiles)
	local mode = territory_mode or "regional"
	local temp_state = {
		board = b,
		stances = {},
		modifiers = {},
		round_stone_effects = {},
		active_effects = {},
		territory_mode = mode,
		distance_modifiers = {
			default_bonus = 0,
			by_stone = {},
			get_bonus = function(self, stone_key, tile_r, tile_c)
				local by_tile = self.by_stone[stone_key]
				if not by_tile then
					return self.default_bonus
				end
				local tile_key = tile_r * 100 + tile_c
				local v = by_tile[tile_key]
				if v == nil then
					return self.default_bonus
				end
				return v
			end,
		},
	}
	effect_manager.apply_phase(temp_state, "distance")
	return finish_resolve_owners(tiles, regions, b, temp_state, mode, false)
end

return M
