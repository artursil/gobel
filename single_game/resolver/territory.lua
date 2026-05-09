--- Territory grid: enclosure/override precedence + per-tile closest-stone Manhattan assignment.
--- @module resolver.territory

local board = require("board")
local config = require("config")
local content = require("content")
local enclosure = require("single_game.resolver.enclosure")
local effect_manager = require("single_game.resolver.effect_manager")

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

--- Returns true when a stone definition includes the "special" tag.
--- @param stone_kind string|nil
--- @return boolean
local function is_special_stone(stone_kind)
	if not stone_kind then
		return false
	end
	local def = content.get_stone(stone_kind)
	if not def or not def.tags then
		return false
	end
	for i = 1, #def.tags do
		if def.tags[i] == "special" then
			return true
		end
	end
	return false
end

--- Collects all occupied stones grouped by owner.
--- Each entry stores row/col/key and whether the stone is tagged as special.
--- @param b table
--- @param n integer
--- @return table A_stones
--- @return table B_stones
local function collect_stones_by_owner(b, n)
	local A_stones, B_stones = {}, {}
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				local owner = color_to_owner(cell.color)
				if owner == "A" or owner == "B" then
					local stone = {
						row = r,
						col = c,
						key = r * 100 + c,
						kind = cell.kind,
						special = is_special_stone(cell.kind),
					}
					if owner == "A" then
						A_stones[#A_stones + 1] = stone
					else
						B_stones[#B_stones + 1] = stone
					end
				end
			end
		end
	end
	return A_stones, B_stones
end

--- Returns nearest effective distance and all nearest contributors for one side.
--- Effective distance = Manhattan distance minus optional distance modifier bonus.
--- @param tile_r integer
--- @param tile_c integer
--- @param stones table
--- @param distance_modifiers table|nil
--- @return number best_distance
--- @return table contributors
local function nearest_effective(tile_r, tile_c, stones, distance_modifiers)
	local best = math.huge
	local contributors = {}
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
			contributors = { { r = stone.row, c = stone.col } }
		elseif d == best then
			contributors[#contributors + 1] = { r = stone.row, c = stone.col }
		end
	end
	return best, contributors
end

--- Resolves owner via nearest-distance rule with nearest-count tie-break.
--- If nearest distances tie, the side with more nearest contributors wins.
--- If both distance and nearest count tie, owner is nil (no-man's-land).
--- @param tile_r integer
--- @param tile_c integer
--- @param A_stones table
--- @param B_stones table
--- @param distance_modifiers table|nil
--- @return "A"|"B"|nil owner
--- @return table nearest_A
--- @return table nearest_B
local function resolve_regular_owner(tile_r, tile_c, A_stones, B_stones, distance_modifiers)
	local da, nearest_A = nearest_effective(tile_r, tile_c, A_stones, distance_modifiers)
	local db, nearest_B = nearest_effective(tile_r, tile_c, B_stones, distance_modifiers)
	if da < db then
		return "A", nearest_A, nearest_B
	end
	if db < da then
		return "B", nearest_A, nearest_B
	end
	if #nearest_A > #nearest_B then
		return "A", nearest_A, nearest_B
	end
	if #nearest_B > #nearest_A then
		return "B", nearest_A, nearest_B
	end
	return nil, nearest_A, nearest_B
end

--- Collects region boundary stones for a given owner.
--- Used to expose enclosure provenance as exact wall-stone coordinates.
--- @param b table
--- @param n integer
--- @param region table|nil
--- @param owner "A"|"B"|nil
--- @return table
local function region_wall_sources(b, n, region, owner)
	if not region or not owner then
		return {}
	end
	local owner_color = owner == "A" and config.STONE_BLACK or config.STONE_WHITE
	local seen = {}
	local out = {}
	local dirs = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }
	for i = 1, #region.tiles do
		local r, c = region.tiles[i][1], region.tiles[i][2]
		for d = 1, #dirs do
			local nr, nc = r + dirs[d][1], c + dirs[d][2]
			if nr >= 1 and nr <= n and nc >= 1 and nc <= n then
				local cell = b[nr][nc]
				if not board.is_empty(cell) and cell.color == owner_color then
					local key = nr * 100 + nc
					if not seen[key] then
						seen[key] = true
						out[#out + 1] = { r = nr, c = nc }
					end
				end
			end
		end
	end
	return out
end

--- Chooses special-stone coordinates for override provenance.
--- Falls back to nearest regular contributors if no special stones exist.
--- @param stones table
--- @param nearest_sources table
--- @return table
local function override_sources(stones, nearest_sources)
	local specials = {}
	for i = 1, #stones do
		if stones[i].special then
			specials[#specials + 1] = { r = stones[i].row, c = stones[i].col }
		end
	end
	if #specials > 0 then
		return specials
	end
	return nearest_sources
end

--- Builds provenance entry for occupied tile.
--- @param row integer
--- @param col integer
--- @param owner "A"|"B"|nil
--- @return table
local function occupied_decision(row, col, owner)
	return {
		mode = "occupied",
		owner = owner,
		contributors = {
			A = owner == "A" and { { r = row, c = col } } or {},
			B = owner == "B" and { { r = row, c = col } } or {},
		},
	}
end

--- Builds provenance entry for regular/tie resolution.
--- @param owner "A"|"B"|nil
--- @param nearest_A table
--- @param nearest_B table
--- @return table
local function regular_decision(owner, nearest_A, nearest_B)
	return {
		mode = owner and "regular" or "tie",
		owner = owner,
		contributors = { A = nearest_A, B = nearest_B },
	}
end

--- Builds provenance entry for enclosure resolution.
--- @param b table
--- @param n integer
--- @param region table|nil
--- @param owner "A"|"B"|nil
--- @param nearest_A table
--- @param nearest_B table
--- @return table
local function enclosure_decision(b, n, region, owner, nearest_A, nearest_B)
	return {
		mode = "enclosure",
		owner = owner,
		contributors = {
			A = owner == "A" and region_wall_sources(b, n, region, "A") or nearest_A,
			B = owner == "B" and region_wall_sources(b, n, region, "B") or nearest_B,
		},
	}
end

--- Builds provenance entry for special override resolution.
--- @param owner "A"|"B"|nil
--- @param A_stones table
--- @param B_stones table
--- @param nearest_A table
--- @param nearest_B table
--- @return table
local function override_decision(owner, A_stones, B_stones, nearest_A, nearest_B)
	return {
		mode = "special_override",
		owner = owner,
		contributors = {
			A = owner == "A" and override_sources(A_stones, nearest_A) or nearest_A,
			B = owner == "B" and override_sources(B_stones, nearest_B) or nearest_B,
		},
	}
end

--- Resolves owner and provenance for one empty tile.
--- Decision order: special override -> enclosure owner -> regular distance/count.
--- @param tile table
--- @param row integer
--- @param col integer
--- @param regions table|nil
--- @param b table
--- @param n integer
--- @param A_stones table
--- @param B_stones table
--- @param distance_modifiers table|nil
--- @param print_debug boolean
--- @return "A"|"B"|nil owner
--- @return table decision
local function resolve_empty_tile(tile, row, col, regions, b, n, A_stones, B_stones, distance_modifiers, print_debug)
	local regular_owner, nearest_A, nearest_B = resolve_regular_owner(row, col, A_stones, B_stones, distance_modifiers)
	if tile.override_owner then
		if print_debug then
			print("[Territory] override at", row, col, "->", tile.override_owner)
		end
		return tile.override_owner, override_decision(tile.override_owner, A_stones, B_stones, nearest_A, nearest_B)
	end
	local region = tile.region_id and regions and regions[tile.region_id] or nil
	if region and region.owner then
		return region.owner, enclosure_decision(b, n, region, region.owner, nearest_A, nearest_B)
	end
	return regular_owner, regular_decision(regular_owner, nearest_A, nearest_B)
end

--- Writes final owner on each tile and returns territory colors plus provenance map.
--- @param tiles table
--- @param regions table|nil
--- @param b table
--- @param state table
--- @param print_debug boolean
--- @return table territory_grid
--- @return table territory_decision_sources
local function finish_resolve_owners(tiles, regions, b, state, print_debug)
	local n = config.BOARD_SIZE
	local territory_grid = {}
	local decision_sources = {}
	local A_stones, B_stones = collect_stones_by_owner(b, n)
	local distance_modifiers = state.distance_modifiers

	for r = 1, n do
		territory_grid[r] = {}
		decision_sources[r] = {}
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				local owner = color_to_owner(cell.color)
				territory_grid[r][c] = cell.color
				decision_sources[r][c] = occupied_decision(r, c, owner)
			else
				local t = tiles[r][c]
				local own, decision = resolve_empty_tile(
					t,
					r,
					c,
					regions,
					b,
					n,
					A_stones,
					B_stones,
					distance_modifiers,
					print_debug
				)
				t.owner = own
				territory_grid[r][c] = owner_to_stone(own)
				decision_sources[r][c] = decision
			end
		end
	end
	return territory_grid, decision_sources
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
	state.territory, state.territory_decision_sources = finish_resolve_owners(tiles, regions, b, state, true)
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
	return finish_resolve_owners(tiles, regions, b, temp_state, false)
end

return M
