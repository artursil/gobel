--- Per-tile influence from stones for territory resolution. Empty cells accumulate
--- inverse-distance-weighted influence from each stone; regional mode restricts by quarter/corner.
--- @module resolver.influence

local board = require("board")
local config = require("config")

local M = {}

local BASE_INFLUENCE = 1

--- @param color any
--- @return string|nil
local function color_to_owner(color)
	if color == config.STONE_BLACK then
		return "A"
	end
	if color == config.STONE_WHITE then
		return "B"
	end
	return nil
end

--- @param row integer
--- @param col integer
--- @return number
local function center_distance(row, col)
	local center = (config.BOARD_SIZE + 1) * 0.5
	return math.abs(row - center) + math.abs(col - center)
end

--- @param row integer
--- @param col integer
--- @return table  Sparse map 1..4 of quarters containing this point (center can sit in more than one)
local function board_quarter(row, col)
	local center = (config.BOARD_SIZE + 1) * 0.5
	local top = row <= center
	local bottom = row >= center
	local left = col <= center
	local right = col >= center
	local quarters = {}
	if top and left then
		quarters[1] = true
	end
	if top and right then
		quarters[2] = true
	end
	if bottom and left then
		quarters[3] = true
	end
	if bottom and right then
		quarters[4] = true
	end
	return quarters
end

--- @param a table
--- @param b table
--- @return boolean
local function quarters_overlap(a, b)
	for q = 1, 4 do
		if a[q] and b[q] then
			return true
		end
	end
	return false
end

--- @param row integer
--- @param col integer
--- @return integer, integer
local function nearest_corner(row, col)
	local n = config.BOARD_SIZE
	local corner_row = (row - 1) <= (n - row) and 1 or n
	local corner_col = (col - 1) <= (n - col) and 1 or n
	return corner_row, corner_col
end

--- @param stone table
--- @param row integer
--- @param col integer
--- @return boolean
local function in_stone_corner_region(stone, row, col)
	return row >= stone.min_row and row <= stone.max_row and col >= stone.min_col and col <= stone.max_col
end

--- @param stone table
--- @param row integer
--- @param col integer
--- @param point_quarter table
--- @param point_center_dist number
--- @return boolean
local function is_outside_candidate(stone, row, col, point_quarter, point_center_dist)
	local same_quarter = quarters_overlap(stone.quarter, point_quarter)
	local within_corner_region = in_stone_corner_region(stone, row, col)
	return same_quarter and stone.center_dist <= point_center_dist and within_corner_region
end

--- Add influence for the stone’s owner onto a single empty cell.
--- @param stone table  Row, col, color, and optional regional fields
--- @param tile_r integer
--- @param tile_c integer
--- @param value number
--- @param tiles table  2D grid of tile state with `influence.A` / `influence.B`
--- @return nil
function M.apply_influence(stone, tile_r, tile_c, value, tiles)
	local owner = color_to_owner(stone.color)
	if not owner or not tiles[tile_r] or not tiles[tile_r][tile_c] then
		return
	end
	tiles[tile_r][tile_c].influence[owner] = tiles[tile_r][tile_c].influence[owner] + value
end

--- Base strength before distance falloff; override for per-stone modifiers.
--- @param _stone table
--- @param _r integer
--- @param _c integer
--- @param _board table
--- @return number
function M.stone_influence_strength(_stone, _r, _c, _board)
	return BASE_INFLUENCE
end

--- @param b table
--- @param regional boolean
--- @return table
local function collect_stones(b, regional)
	local n = config.BOARD_SIZE
	local stones = {}
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				local entry = { row = r, col = c, color = cell.color, kind = cell.kind }
				if regional then
					local cr, cc = nearest_corner(r, c)
					entry.center_dist = center_distance(r, c)
					entry.quarter = board_quarter(r, c)
					entry.min_row = math.min(r, cr)
					entry.max_row = math.max(r, cr)
					entry.min_col = math.min(c, cc)
					entry.max_col = math.max(c, cc)
				end
				stones[#stones + 1] = entry
			end
		end
	end
	return stones
end

--- @param stone table
--- @param r integer
--- @param c integer
--- @param regional boolean
--- @return boolean
local function stone_filters_tile(stone, r, c, regional)
	if not regional then
		return true
	end
	local point_quarter = board_quarter(r, c)
	local point_center_dist = center_distance(r, c)
	return is_outside_candidate(stone, r, c, point_quarter, point_center_dist)
end

--- Accumulate influence on one empty cell from all stones that pass the regional filter.
--- @param stones table  List of stone descriptors from `collect_stones`
--- @param row integer
--- @param col integer
--- @param b table  Board grid
--- @param tiles table  2D tile state
--- @param regional boolean  If true, use quarter/corner filtering; if false, full board
--- @return nil
local function apply_tile_influence_from_stones(stones, row, col, b, tiles, regional)
	for i = 1, #stones do
		local stone = stones[i]
		if stone_filters_tile(stone, row, col, regional) then
			local distance = math.max(1, math.abs(row - stone.row) + math.abs(col - stone.col))
			local strength = M.stone_influence_strength(stone, row, col, b)
			local value = strength / distance
			M.apply_influence(stone, row, col, value, tiles)
		end
	end
end

--- Fills `tiles` with A/B influence for every cell. Occupied cells zero out influence.
--- @param b table  Board grid
--- @param territory_mode string  `"regional"` or `"distance_only"`
--- @param tiles table  2D grid; each cell has `influence` table
--- @return nil
function M.build_influence_map(b, territory_mode, tiles)
	local n = config.BOARD_SIZE
	local regional = territory_mode ~= "distance_only"
	local stones = collect_stones(b, regional)
	for r = 1, n do
		for c = 1, n do
			if not board.is_empty(b[r][c]) then
				tiles[r][c].influence.A = 0
				tiles[r][c].influence.B = 0
			else
				apply_tile_influence_from_stones(stones, r, c, b, tiles, regional)
			end
		end
	end
end

return M
