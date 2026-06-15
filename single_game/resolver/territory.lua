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
--- @return "B"|"W"|nil
local function color_to_owner(color)
	if color == config.STONE_BLACK then
		return config.OWNER_BLACK
	end
	if color == config.STONE_WHITE then
		return config.OWNER_WHITE
	end
	return nil
end


--- @return table
local function new_tile()
	return {
		influence = { B = 0, W = 0 },
		region_id = nil,
		override_owner = nil,
		override_contested = false,
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
	if owner == config.OWNER_BLACK then
		return config.STONE_BLACK
	end
	if owner == config.OWNER_WHITE then
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
--- @return table black_stones
--- @return table white_stones
local function collect_stones_by_owner(b, n)
	local black_stones, white_stones = {}, {}
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				local owner = color_to_owner(cell.color)
				if owner == config.OWNER_BLACK or owner == config.OWNER_WHITE then
					local stone = {
						row = r,
						col = c,
						key = r * 100 + c,
						kind = cell.kind,
						special = is_special_stone(cell.kind),
					}
					if owner == config.OWNER_BLACK then
						black_stones[#black_stones + 1] = stone
					else
						white_stones[#white_stones + 1] = stone
					end
				end
			end
		end
	end
	return black_stones, white_stones
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
--- @param black_stones table
--- @param white_stones table
--- @param distance_modifiers table|nil
--- @return "B"|"W"|nil owner
--- @return table nearest_black
--- @return table nearest_white
local function resolve_regular_owner(tile_r, tile_c, black_stones, white_stones, distance_modifiers)
	local da, nearest_black = nearest_effective(tile_r, tile_c, black_stones, distance_modifiers)
	local db, nearest_white = nearest_effective(tile_r, tile_c, white_stones, distance_modifiers)
	if da < db then
		return config.OWNER_BLACK, nearest_black, nearest_white
	end
	if db < da then
		return config.OWNER_WHITE, nearest_black, nearest_white
	end
	if #nearest_black > #nearest_white then
		return config.OWNER_BLACK, nearest_black, nearest_white
	end
	if #nearest_white > #nearest_black then
		return config.OWNER_WHITE, nearest_black, nearest_white
	end
	return nil, nearest_black, nearest_white
end

--- Collects region boundary stones for a given owner.
--- Used to expose enclosure provenance as exact wall-stone coordinates.
--- @param b table
--- @param n integer
--- @param region table|nil
--- @param owner "B"|"W"|nil
--- @return table
local function region_wall_sources(b, n, region, owner)
	if not region or not owner then
		return {}
	end
	local owner_color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
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
--- @param owner "B"|"W"|nil
--- @return table
local function occupied_decision(row, col, owner)
	return {
		mode = "occupied",
		owner = owner,
		contributors = {
			B = owner == config.OWNER_BLACK and { { r = row, c = col } } or {},
			W = owner == config.OWNER_WHITE and { { r = row, c = col } } or {},
		},
	}
end

--- Builds provenance entry for regular/tie resolution.
--- @param owner "B"|"W"|nil
--- @param nearest_black table
--- @param nearest_white table
--- @return table
local function regular_decision(owner, nearest_black, nearest_white)
	return {
		mode = owner and "regular" or "tie",
		owner = owner,
		contributors = { B = nearest_black, W = nearest_white },
	}
end

--- Collects full enclosure wall boundary contributors for a tile.
--- Uses persisted wall records from state, so UI can show the complete wall
--- that actually influences final enclosure ownership for this tile.
--- @param walls table[]|nil
--- @param row integer
--- @param col integer
--- @param owner "B"|"W"|nil
--- @param fallback table
--- @return table
local function enclosure_sources_for_tile(walls, row, col, owner, fallback)
	if not walls or not owner then
		return fallback
	end
	local key = row * 100 + col
	local seen = {}
	local out = {}
	for i = 1, #walls do
		local wall = walls[i]
		if wall.owner == owner then
			local inside_match = false
			for j = 1, #wall.inside_fields do
				local ir, ic = wall.inside_fields[j][1], wall.inside_fields[j][2]
				if (ir * 100 + ic) == key then
					inside_match = true
					break
				end
			end
			if inside_match then
				for j = 1, #wall.boundary_fields do
					local br, bc = wall.boundary_fields[j][1], wall.boundary_fields[j][2]
					local bkey = br * 100 + bc
					if not seen[bkey] then
						seen[bkey] = true
						out[#out + 1] = { r = br, c = bc }
					end
				end
			end
		end
	end
	if #out > 0 then
		return out
	end
	return fallback
end

--- Builds provenance entry for enclosure resolution.
--- @param walls table[]|nil
--- @param row integer
--- @param col integer
--- @param owner "B"|"W"|nil
--- @param nearest_black table
--- @param nearest_white table
--- @return table
local function enclosure_decision(walls, row, col, owner, nearest_black, nearest_white)
	return {
		mode = "enclosure",
		owner = owner,
		contributors = {
			B = owner == config.OWNER_BLACK and enclosure_sources_for_tile(walls, row, col, config.OWNER_BLACK, nearest_black)
				or nearest_black,
			W = owner == config.OWNER_WHITE and enclosure_sources_for_tile(walls, row, col, config.OWNER_WHITE, nearest_white)
				or nearest_white,
		},
	}
end

--- Builds provenance entry for special override resolution.
--- @param owner "B"|"W"|nil
--- @param black_stones table
--- @param white_stones table
--- @param nearest_black table
--- @param nearest_white table
--- @return table
local function override_decision(owner, black_stones, white_stones, nearest_black, nearest_white)
	return {
		mode = "special_override",
		owner = owner,
		contributors = {
			B = owner == config.OWNER_BLACK and override_sources(black_stones, nearest_black) or nearest_black,
			W = owner == config.OWNER_WHITE and override_sources(white_stones, nearest_white) or nearest_white,
		},
	}
end

--- Builds provenance entry when opposing control overrides cancel on the same cell.
--- @param nearest_black table
--- @param nearest_white table
--- @return table
local function override_contested_decision(nearest_black, nearest_white)
	return {
		mode = "override_contested",
		owner = nil,
		contributors = { B = nearest_black, W = nearest_white },
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
--- @param black_stones table
--- @param white_stones table
--- @param distance_modifiers table|nil
--- @param walls table[]|nil
--- @param print_debug boolean
--- @return "B"|"W"|nil owner
--- @return table decision
local function resolve_empty_tile(tile, row, col, regions, walls, black_stones, white_stones, distance_modifiers, print_debug)
	local regular_owner, nearest_black, nearest_white =
		resolve_regular_owner(row, col, black_stones, white_stones, distance_modifiers)
	if tile.override_contested then
		if print_debug then
			print("[Territory] override contested at", row, col)
		end
		return nil, override_contested_decision(nearest_black, nearest_white)
	end
	if tile.override_owner then
		if print_debug then
			print("[Territory] override at", row, col, "->", tile.override_owner)
		end
		return tile.override_owner,
			override_decision(tile.override_owner, black_stones, white_stones, nearest_black, nearest_white)
	end
	local region = tile.region_id and regions and regions[tile.region_id] or nil
	if region and region.owner then
		return region.owner, enclosure_decision(walls, row, col, region.owner, nearest_black, nearest_white)
	end
	return regular_owner, regular_decision(regular_owner, nearest_black, nearest_white)
end

--- Writes final owner on each tile and returns territory colors plus provenance map.
--- @param tiles table
--- @param regions table|nil
--- @param b table
--- @param state table
--- @param walls table[]|nil
--- @param print_debug boolean
--- @return table territory_grid
--- @return table territory_decision_sources
local function finish_resolve_owners(tiles, regions, walls, b, state, print_debug)
	local n = config.BOARD_SIZE
	local territory_grid = {}
	local decision_sources = {}
	local black_stones, white_stones = collect_stones_by_owner(b, n)
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
					walls,
					black_stones,
					white_stones,
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

--- @param territory_grid table
--- @param row integer
--- @param col integer
--- @return "B"|"W"|nil
function M.owner_at_territory_cell(territory_grid, row, col)
	local row_cells = territory_grid[row]
	if not row_cells then
		return nil
	end
	local color = row_cells[col]
	if color == config.STONE_BLACK then
		return config.OWNER_BLACK
	end
	if color == config.STONE_WHITE then
		return config.OWNER_WHITE
	end
	return nil
end

--- Weighted territory total for one owner on the current territory grid (matches ``spec_helper.territory_points``).
--- @param state table
--- @param owner "B"|"W"
--- @return integer
function M.total_territory_for_owner(state, owner)
	local territory_grid = state.territory
	if not territory_grid then
		return 0
	end
	local color = owner == config.OWNER_BLACK and config.STONE_BLACK or config.STONE_WHITE
	local territory_value = state.territory_value or {}
	local n = config.BOARD_SIZE
	local sum = 0
	for r = 1, n do
		local row_cells = territory_grid[r]
		if row_cells then
			for c = 1, n do
				if row_cells[c] == color then
					local weight = (territory_value[r] and territory_value[r][c]) or 1
					sum = sum + weight
				end
			end
		end
	end
	return sum
end

--- @param state table
--- @return integer black
--- @return integer white
function M.count_controlled_totals(state)
	if not state.territory then
		return 0, 0
	end
	return count_controlled(state.territory, state.board, state)
end

--- Territory owner at ``row,col`` if the stone cell were empty, using the current assignment pass tiles.
--- @param state table
--- @param row integer
--- @param col integer
--- @return "B"|"W"|nil
function M.hypothetical_empty_owner(state, row, col)
	local tiles = state.territory_tiles
	local b = state.board
	if not tiles or not b then
		return nil
	end
	local n = config.BOARD_SIZE
	local black_stones, white_stones = collect_stones_by_owner(b, n)
	local tile = tiles[row] and tiles[row][col]
	if not tile then
		return nil
	end
	local owner = resolve_empty_tile(
		tile,
		row,
		col,
		state.regions,
		state.enclosure_walls,
		black_stones,
		white_stones,
		state.distance_modifiers,
		false
	)
	return owner
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
	state.enclosure_walls = enclosure.extract_walls(b)
	state.regions = enclosure.detect_regions_and_ownership(b, tiles)
	if config.TERRITORY_DEBUG then
		print("[Territory] region count", region_count(state.regions))
	end
end

--- Sets `state.territory` and updates `scores.territory` from controlled cell counts.
--- @param state table
--- @return nil
function M.finish_assignment(state)
	local b = state.board
	local tiles = state.territory_tiles
	local regions = state.regions
	local walls = state.enclosure_walls
	if not tiles then
		return
	end
	state.territory, state.territory_decision_sources =
		finish_resolve_owners(tiles, regions, walls, b, state, config.TERRITORY_DEBUG)
	local black_c, white_c = count_controlled(state.territory, b, state)
	state.scores.territory.B = black_c
	state.scores.territory.W = white_c
end

--- Standalone helper: no `state` mutation. Runs distance- and territory-phase board stone effects (per-cell
--- ``territory_value``), then ownership resolution.
--- @param b table
--- @param territory_mode string|nil
--- @return table territory_grid
--- @return table territory_decision_sources
--- @return table territory_value  per-cell multipliers (default ``1``); tower corner adds ``+1`` in its block.
function M.compute_from_board(b, territory_mode)
	local tiles = init_tiles(b)
	local walls = enclosure.extract_walls(b)
	local regions = enclosure.detect_regions_and_ownership(b, tiles)
	local mode = territory_mode or "regional"
	local n = config.BOARD_SIZE
	local territory_value = {}
	for r = 1, n do
		territory_value[r] = {}
		for c = 1, n do
			territory_value[r][c] = 1
		end
	end
	local temp_state = {
		board = b,
		players = {
			black = { stances = { fixed = {}, swappable = {} } },
			white = { stances = { fixed = {}, swappable = {} } },
		},
		temporary_stances = {},
		just_played = {},
		played_cards = {},
		round_stone_effects = {},
		active_effects = {},
		territory_mode = mode,
		territory_value = territory_value,
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
	local scoring_phases = require("single_game.resolver.scoring_phases")
	effect_manager.apply_sub_phase(temp_state, "playing_stones", "territory", scoring_phases.TERRITORY_STEP_DISTANCE)
	temp_state.territory_tiles = tiles
	temp_state.enclosure_walls = walls
	temp_state.regions = regions
	effect_manager.apply_sub_phase(temp_state, "playing_stones", "territory", scoring_phases.TERRITORY_STEP_VALUE)
	effect_manager.apply_sub_phase(temp_state, "playing_stones", "territory", scoring_phases.TERRITORY_STEP_OVERRIDE)
	local territory_grid, decision_sources = finish_resolve_owners(tiles, regions, walls, b, temp_state, false)
	return territory_grid, decision_sources, temp_state.territory_value
end

--- Maps a territory grid cell color to a scoring owner token.
--- @param territory_color integer|nil
--- @return string|nil ``config.OWNER_BLACK`` | ``config.OWNER_WHITE`` | nil when contested or unowned
function M.owner_from_territory_color(territory_color)
	if territory_color == config.STONE_BLACK then
		return config.OWNER_BLACK
	end
	if territory_color == config.STONE_WHITE then
		return config.OWNER_WHITE
	end
	return nil
end

--- Territory owner at one grid cell from a territory map snapshot.
--- @param territory_grid table
--- @param row integer
--- @param col integer
--- @return string|nil
function M.owner_at_cell(territory_grid, row, col)
	if not territory_grid or not territory_grid[row] then
		return nil
	end
	return M.owner_from_territory_color(territory_grid[row][col])
end

--- Weighted total controlled territory for one side across the full grid.
--- @param territory_grid table
--- @param color integer ``config.STONE_BLACK`` | ``config.STONE_WHITE``
--- @param territory_value table|nil
--- @return integer
function M.weighted_territory_points(territory_grid, color, territory_value)
	local n = config.BOARD_SIZE
	local sum = 0
	for r = 1, n do
		for c = 1, n do
			if territory_grid[r][c] == color then
				if territory_value then
					local weight = (territory_value[r] and territory_value[r][c]) or 1
					sum = sum + weight
				else
					sum = sum + 1
				end
			end
		end
	end
	return sum
end

local stone_params = require("objects.parameters.stones")

--- Computes end-of-turn territory-to-points payout from total controlled territory.
--- @param total_territory integer
--- @return integer
function M.territory_to_points_payout(total_territory)
	return math.min(
		stone_params.t2p_cap,
		math.floor(total_territory / stone_params.t2p_divisor)
	)
end

--- @param state table
--- @param row integer
--- @param col integer
--- @return table territory_grid
--- @return table territory_value
local function territory_map_for_stone_cell(state, row, col)
	local key = row .. ":" .. col
	local snapshots = state.territory_placement_snapshots
	if snapshots and snapshots[key] then
		local snapshot = snapshots[key]
		snapshots[key] = nil
		return snapshot.territory, snapshot.territory_value
	end
	local cell = state.board[row] and state.board[row][col]
	if cell and not board.is_empty(cell) then
		local cloned = board.clone(state.board)
		cloned[row][col] = config.STONE_NONE
		local territory_grid, _, territory_value =
			M.compute_from_board(cloned, state.territory_mode or "regional")
		return territory_grid, territory_value
	end
	return state.territory, state.territory_value
end

--- Territory map used by territory-to-points stones at payout time.
--- @param state table
--- @param row integer
--- @param col integer
--- @return table territory_grid
--- @return table territory_value
function M.territory_map_for_stone_payout(state, row, col)
	return territory_map_for_stone_cell(state, row, col)
end

--- Stores the pre-placement territory snapshot for stones that read ownership on their placement turn.
--- @param state table
--- @param row integer
--- @param col integer
--- @param stone_id string
--- @return nil
function M.capture_placement_snapshot_if_needed(state, row, col, stone_id)
	local def = content.get_stone(stone_id)
	if not def or not def.effects then
		return
	end
	local needs_snapshot = false
	for i = 1, #def.effects do
		local effect_name = def.effects[i].effect_name
		if effect_name == "territory_to_points"
			or effect_name == "territory_to_multiplier_snapshot"
			or effect_name == "territory_to_multiplier" then
			needs_snapshot = true
			break
		end
	end
	if not needs_snapshot then
		return
	end
	local mode = state.territory_mode or "regional"
	local territory_grid, _, territory_value = M.compute_from_board(state.board, mode)
	state.territory_placement_snapshots = state.territory_placement_snapshots or {}
	state.territory_placement_snapshots[row .. ":" .. col] = {
		territory = territory_grid,
		territory_value = territory_value,
	}
end

return M
