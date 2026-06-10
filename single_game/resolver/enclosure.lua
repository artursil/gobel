local board = require("board")
local config = require("config")

local M = {}

local ORTHO = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
local DIAG = { { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }

local function neighbor(r, c, n, dr, dc)
	local nr, nc = r + dr, c + dc
	if nr < 1 or nr > n or nc < 1 or nc > n then
		return nil
	end
	return nr, nc
end

local function cell_key(r, c)
	return r * 100 + c
end

local function color_to_owner(color)
	if color == config.STONE_BLACK then
		return config.OWNER_BLACK
	end
	if color == config.STONE_WHITE then
		return config.OWNER_WHITE
	end
	return nil
end

local function owner_from_colors(colors)
	local has_black, has_white = false, false
	for i = 1, #colors do
		local owner = color_to_owner(colors[i])
		if owner == config.OWNER_BLACK then
			has_black = true
		end
		if owner == config.OWNER_WHITE then
			has_white = true
		end
	end
	if has_black and not has_white then
		return config.OWNER_BLACK
	end
	if has_white and not has_black then
		return config.OWNER_WHITE
	end
	return nil
end

local function init_visited(n)
	local visited = {}
	for r = 1, n do
		visited[r] = {}
		for c = 1, n do
			visited[r][c] = false
		end
	end
	return visited
end

local function edge_count(edges)
	local count = 0
	if edges.top then count = count + 1 end
	if edges.bottom then count = count + 1 end
	if edges.left then count = count + 1 end
	if edges.right then count = count + 1 end
	return count
end

local function touches_opposite_edges(edges)
	return (edges.top and edges.bottom) or (edges.left and edges.right)
end

local function is_open_region(edges)
	local count = edge_count(edges)
	if count > 2 then
		return true
	end
	if count == 2 and touches_opposite_edges(edges) then
		return true
	end
	return false
end

local function collect_region_boundary_owner_stones(b, n, cells, owner_color)
	local seen = {}
	local out = {}
	for i = 1, #cells do
		local r, c = cells[i][1], cells[i][2]
		for _, dirs in ipairs({ ORTHO, DIAG }) do
			for d = 1, #dirs do
				local nr, nc = neighbor(r, c, n, dirs[d][1], dirs[d][2])
				if nr then
					local cell = b[nr][nc]
					if not board.is_empty(cell) and cell.color == owner_color then
						local key = cell_key(nr, nc)
						if not seen[key] then
							seen[key] = true
							out[#out + 1] = { nr, nc }
						end
					end
				end
			end
		end
	end
	return out
end

local function collect_passable_regions_for_owner(b, n, owner_color)
	local visited = init_visited(n)
	local regions = {}

	local function passable(r, c)
		local cell = b[r][c]
		return board.is_empty(cell) or cell.color ~= owner_color
	end

	for r = 1, n do
		for c = 1, n do
			if not visited[r][c] and passable(r, c) then
				local queue = { { r, c } }
				local head = 1
				visited[r][c] = true
				local cells = {}
				local edges = { top = false, bottom = false, left = false, right = false }
				while head <= #queue do
					local cur = queue[head]
					head = head + 1
					local cr, cc = cur[1], cur[2]
					cells[#cells + 1] = { cr, cc }
					if cr == 1 then edges.top = true end
					if cr == n then edges.bottom = true end
					if cc == 1 then edges.left = true end
					if cc == n then edges.right = true end
					for i = 1, #ORTHO do
						local nr, nc = neighbor(cr, cc, n, ORTHO[i][1], ORTHO[i][2])
						if nr and not visited[nr][nc] and passable(nr, nc) then
							visited[nr][nc] = true
							queue[#queue + 1] = { nr, nc }
						end
					end
				end
				regions[#regions + 1] = { cells = cells, edges = edges }
			end
		end
	end

	return regions
end

local function boundary_component_count(boundary_fields, n)
	if #boundary_fields == 0 then
		return 0
	end
	local by_key = {}
	for i = 1, #boundary_fields do
		local r, c = boundary_fields[i][1], boundary_fields[i][2]
		by_key[cell_key(r, c)] = { r = r, c = c }
	end
	local visited = {}
	local components = 0
	for key, field in pairs(by_key) do
		if not visited[key] then
			components = components + 1
			local stack = { field }
			visited[key] = true
			while #stack > 0 do
				local cur = table.remove(stack)
				for _, dirs in ipairs({ ORTHO, DIAG }) do
					for d = 1, #dirs do
						local nr, nc = neighbor(cur.r, cur.c, n, dirs[d][1], dirs[d][2])
						if nr then
							local nk = cell_key(nr, nc)
							if by_key[nk] and not visited[nk] then
								visited[nk] = true
								stack[#stack + 1] = by_key[nk]
							end
						end
					end
				end
			end
		end
	end
	return components
end

local function split_boundary_components(boundary_fields, n)
	local by_key = {}
	for i = 1, #boundary_fields do
		local r, c = boundary_fields[i][1], boundary_fields[i][2]
		by_key[cell_key(r, c)] = { r = r, c = c }
	end
	local visited = {}
	local components = {}
	for key, field in pairs(by_key) do
		if not visited[key] then
			local stack = { field }
			visited[key] = true
			local component = {}
			while #stack > 0 do
				local cur = table.remove(stack)
				component[#component + 1] = { cur.r, cur.c }
				for _, dirs in ipairs({ ORTHO, DIAG }) do
					for d = 1, #dirs do
						local nr, nc = neighbor(cur.r, cur.c, n, dirs[d][1], dirs[d][2])
						if nr then
							local nk = cell_key(nr, nc)
							if by_key[nk] and not visited[nk] then
								visited[nk] = true
								stack[#stack + 1] = by_key[nk]
							end
						end
					end
				end
			end
			components[#components + 1] = component
		end
	end
	return components
end

local function split_cells_by_blocked(boundary_fields, n)
	local blocked = {}
	for i = 1, #boundary_fields do
		local r, c = boundary_fields[i][1], boundary_fields[i][2]
		blocked[cell_key(r, c)] = true
	end
	local visited = init_visited(n)
	local components = {}
	for r = 1, n do
		for c = 1, n do
			if not visited[r][c] and not blocked[cell_key(r, c)] then
				local queue = { { r, c } }
				local head = 1
				visited[r][c] = true
				local cells = {}
				while head <= #queue do
					local cur = queue[head]
					head = head + 1
					local cr, cc = cur[1], cur[2]
					cells[#cells + 1] = { cr, cc }
					for i = 1, #ORTHO do
						local nr, nc = neighbor(cr, cc, n, ORTHO[i][1], ORTHO[i][2])
						if nr and not visited[nr][nc] and not blocked[cell_key(nr, nc)] then
							visited[nr][nc] = true
							queue[#queue + 1] = { nr, nc }
						end
					end
				end
				components[#components + 1] = cells
			end
		end
	end
	return components
end

local function is_a_proper_boundary(boundary_fields, n)
	local regions = split_cells_by_blocked(boundary_fields, n)
	return #regions == 2
end

local function choose_biggest_boundary(components)
	if #components == 0 then
		return nil
	end
	local biggest = components[1]
	for i = 2, #components do
		if #components[i] > #biggest then
			biggest = components[i]
		end
	end
	return biggest
end

local function inside_for_boundary(boundary_fields, n)
	local regions = split_cells_by_blocked(boundary_fields, n)
	if #regions ~= 2 then
		return nil
	end
	if #regions[1] <= #regions[2] then
		return regions[1]
	end
	return regions[2]
end

local function boundary_signature(boundary_fields)
	local keys = {}
	for i = 1, #boundary_fields do
		keys[#keys + 1] = tostring(cell_key(boundary_fields[i][1], boundary_fields[i][2]))
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

function M.extract_walls(b)
	local n = config.BOARD_SIZE
	local walls = {}
	local owners = {
		{ owner = config.OWNER_BLACK, color = config.STONE_BLACK },
		{ owner = config.OWNER_WHITE, color = config.STONE_WHITE },
	}
	local seen_signatures = {}

	for i = 1, #owners do
		local owner = owners[i]
		local passable_regions = collect_passable_regions_for_owner(b, n, owner.color)
		for j = 1, #passable_regions do
			local region = passable_regions[j]
			if not is_open_region(region.edges) then
				local boundary = collect_region_boundary_owner_stones(b, n, region.cells, owner.color)
				local colors = {}
				for k = 1, #boundary do
					colors[#colors + 1] = owner.color
				end
				if #boundary > 0 and owner_from_colors(colors) == owner.owner then
					local raw_components = split_boundary_components(boundary, n)
					local proper_components = {}
					for c = 1, #raw_components do
						if is_a_proper_boundary(raw_components[c], n) then
							proper_components[#proper_components + 1] = raw_components[c]
						end
					end
					local chosen_boundary = choose_biggest_boundary(proper_components)
					local inside_fields = chosen_boundary and inside_for_boundary(chosen_boundary, n) or nil
					local signature = chosen_boundary and boundary_signature(chosen_boundary) or nil
					if chosen_boundary and inside_fields and signature and not seen_signatures[signature] then
						seen_signatures[signature] = true
					walls[#walls + 1] = {
						owner = owner.owner,
							boundary_fields = chosen_boundary,
							inside_fields = inside_fields,
							field_count = #inside_fields,
					}
					end
				end
			end
		end
	end

	return walls
end

local function collect_empty_regions(b, tiles, n)
	local visited = init_visited(n)
	local regions = {}
	local next_id = 1
	for r = 1, n do
		for c = 1, n do
			if not visited[r][c] and board.is_empty(b[r][c]) then
				local id = next_id
				next_id = next_id + 1
				local queue = { { r, c } }
				local head = 1
				visited[r][c] = true
				local region_tiles = {}
				while head <= #queue do
					local cur = queue[head]
					head = head + 1
					local cr, cc = cur[1], cur[2]
					tiles[cr][cc].region_id = id
					region_tiles[#region_tiles + 1] = { cr, cc }
					for i = 1, #ORTHO do
						local nr, nc = neighbor(cr, cc, n, ORTHO[i][1], ORTHO[i][2])
						if nr and not visited[nr][nc] and board.is_empty(b[nr][nc]) then
							visited[nr][nc] = true
							queue[#queue + 1] = { nr, nc }
						end
					end
				end
				regions[id] = { id = id, tiles = region_tiles, size = #region_tiles, boundary = {}, owner = nil }
			end
		end
	end
	return regions
end

local function collect_region_boundary_colors(b, n, region_tiles)
	local seen = {}
	local out = {}
	for i = 1, #region_tiles do
		local r, c = region_tiles[i][1], region_tiles[i][2]
		for _, dirs in ipairs({ ORTHO, DIAG }) do
			for d = 1, #dirs do
				local nr, nc = neighbor(r, c, n, dirs[d][1], dirs[d][2])
				if nr and not board.is_empty(b[nr][nc]) then
					local key = cell_key(nr, nc)
					if not seen[key] then
						seen[key] = true
						out[#out + 1] = b[nr][nc].color
					end
				end
			end
		end
	end
	return out
end

local function assign_empty_owners_from_walls(walls)
	--- Builds a lookup set for each wall's interior cells.
	--- Example: if wall #2 contains inside fields {(4,4), (4,5)}, `sets[2][404]` and `sets[2][405]` are true.
	--- This lets later conflict checks run in O(1) per cell-key membership test.
	--- @param list table[] Array of wall records containing `inside_fields`.
	--- @return table<integer, table<integer, boolean>> inside_sets Index-aligned cell-key sets.
	local function build_inside_sets(list)
		local sets = {}
		for i = 1, #list do
			local set = {}
			for j = 1, #list[i].inside_fields do
				local r, c = list[i].inside_fields[j][1], list[i].inside_fields[j][2]
				set[cell_key(r, c)] = true
			end
			sets[i] = set
		end
		return sets
	end

	--- Counts entries in a set-like table.
	--- Example: a set with keys {101=true, 102=true, 103=true} returns 3.
	--- @param set table<integer, boolean>
	--- @return integer count
	local function set_size(set)
		local n = 0
		for _ in pairs(set) do
			n = n + 1
		end
		return n
	end

	--- Checks whether two inside-field sets share at least one cell.
	--- Example: A={101,102}, B={102,103} => true.
	--- @param a table<integer, boolean>
	--- @param b table<integer, boolean>
	--- @return boolean intersects
	local function sets_intersect(a, b)
		for k in pairs(a) do
			if b[k] then
				return true
			end
		end
		return false
	end

	--- Returns true when set `a` fully contains every key from set `b`.
	--- Example: A={101,102,103}, B={102,103} => true.
	--- @param a table<integer, boolean>
	--- @param b table<integer, boolean>
	--- @return boolean contains
	local function set_contains(a, b)
		for k in pairs(b) do
			if not a[k] then
				return false
			end
		end
		return true
	end

	--- Determines whether two enclosure interiors geometrically cross (overlap without containment).
	--- Crossing means ambiguous ownership and must resolve to neutral for shared cells.
	--- Examples:
	--- - Nested: A contains B entirely -> false (not crossing, smallest can win).
	--- - Disjoint: A and B do not overlap -> false.
	--- - Overlap without containment: A∩B non-empty and neither contains the other -> true.
	--- @param a_set table<integer, boolean>
	--- @param b_set table<integer, boolean>
	--- @return boolean crosses
	local function walls_cross(a_set, b_set)
		if not sets_intersect(a_set, b_set) then
			return false
		end
		if set_contains(a_set, b_set) or set_contains(b_set, a_set) then
			return false
		end
		return true
	end

	--- Resolves owner for one empty cell from all wall candidates covering that cell.
	--- Strategy:
	--- 1) Single candidate -> that owner.
	--- 2) Multiple smallest candidates with different owners -> neutral.
	--- 3) Unique smallest owner vs opposite-owner candidates:
	---    - crossing interiors -> neutral
	---    - nested containment or disjoint -> smallest owner wins.
	--- Example use-cases:
	--- - A tiny black pocket fully inside a larger white area: black wins for that cell.
	--- - Black and white enclosures crossing over same cell: cell becomes no-man's-land (nil).
	--- @param candidates table[] Array of { index: integer, owner: "B"|"W", field_count: integer }.
	--- @param inside_sets table<integer, table<integer, boolean>> Wall index -> inside cell-key set.
	--- @return string|nil owner `"B"`, `"W"`, or nil when ambiguous/contested.
	local function resolve_cell_owner(candidates, inside_sets)
		if #candidates == 0 then
			return nil
		end
		if #candidates == 1 then
			return candidates[1].owner
		end
		table.sort(candidates, function(a, b)
			if a.field_count == b.field_count then
				return a.index < b.index
			end
			return a.field_count < b.field_count
		end)
		local smallest = candidates[1]
		for i = 2, #candidates do
			if candidates[i].field_count ~= smallest.field_count then
				break
			end
			if candidates[i].owner ~= smallest.owner then
				return nil
			end
		end
		for i = 1, #candidates do
			local other = candidates[i]
			if other.owner ~= smallest.owner then
				local a_set = inside_sets[smallest.index]
				local b_set = inside_sets[other.index]
				if walls_cross(a_set, b_set) then
					return nil
				end
			end
		end
		return smallest.owner
	end

	local inside_sets = build_inside_sets(walls)
	local candidates_by_cell = {}
	for i = 1, #walls do
		local wall = walls[i]
		for j = 1, #wall.inside_fields do
			local r, c = wall.inside_fields[j][1], wall.inside_fields[j][2]
			local key = cell_key(r, c)
			candidates_by_cell[key] = candidates_by_cell[key] or {}
			candidates_by_cell[key][#candidates_by_cell[key] + 1] = {
				index = i,
				owner = wall.owner,
				field_count = wall.field_count,
			}
		end
	end
	local map = {}
	for key, candidates in pairs(candidates_by_cell) do
		map[key] = resolve_cell_owner(candidates, inside_sets)
	end
	return map
end

local function apply_region_owner_from_map(regions, owner_map)
	for _, region in pairs(regions) do
		local owner = nil
		local mixed = false
		for i = 1, #region.tiles do
			local r, c = region.tiles[i][1], region.tiles[i][2]
			local t = owner_map[cell_key(r, c)]
			if t then
				if owner == nil then owner = t elseif owner ~= t then mixed = true end
			end
		end
		region.owner = mixed and nil or owner
	end
end

--- @param wall table
--- @param row integer
--- @param col integer
--- @return boolean
function M.wall_contains_cell(wall, row, col)
	local key = cell_key(row, col)
	for j = 1, #wall.inside_fields do
		local ir, ic = wall.inside_fields[j][1], wall.inside_fields[j][2]
		if cell_key(ir, ic) == key then
			return true
		end
	end
	for j = 1, #wall.boundary_fields do
		local br, bc = wall.boundary_fields[j][1], wall.boundary_fields[j][2]
		if cell_key(br, bc) == key then
			return true
		end
	end
	return false
end

--- Returns walls of ``owner`` whose region contains ``row,col`` (interior or boundary).
--- @param walls table[]
--- @param row integer
--- @param col integer
--- @param owner string
--- @return table[]
function M.walls_containing_cell(walls, row, col, owner)
	local out = {}
	for i = 1, #walls do
		local wall = walls[i]
		if wall.owner == owner and M.wall_contains_cell(wall, row, col) then
			out[#out + 1] = wall
		end
	end
	return out
end

--- Smallest qualifying owner enclosure containing the cell; nil when none.
--- @param b table
--- @param row integer
--- @param col integer
--- @param owner string
--- @return table|nil
function M.innermost_wall_containing(b, row, col, owner)
	local walls = M.extract_walls(b)
	local candidates = M.walls_containing_cell(walls, row, col, owner)
	if #candidates == 0 then
		return nil
	end
	local best = candidates[1]
	for i = 2, #candidates do
		if candidates[i].field_count < best.field_count then
			best = candidates[i]
		end
	end
	return best
end

--- @param outer table
--- @param inner table
--- @return boolean
function M.wall_encloses_wall(outer, inner)
	for i = 1, #inner.inside_fields do
		local r, c = inner.inside_fields[i][1], inner.inside_fields[i][2]
		if not M.wall_contains_cell(outer, r, c) then
			return false
		end
	end
	return true
end

--- Counts opponent stones in ``wall`` interior, excluding nested opponent enclosures.
--- @param b table
--- @param wall table
--- @param owner string
--- @return integer
function M.count_enemy_stones_in_wall(b, wall, owner)
	local opponent = owner == config.OWNER_BLACK and config.OWNER_WHITE or config.OWNER_BLACK
	local enemy_color = owner == config.OWNER_BLACK and config.STONE_WHITE or config.STONE_BLACK
	local all_walls = M.extract_walls(b)
	local excluded = {}
	for i = 1, #all_walls do
		local nested = all_walls[i]
		if nested.owner == opponent and M.wall_encloses_wall(wall, nested) then
			for j = 1, #nested.inside_fields do
				local r, c = nested.inside_fields[j][1], nested.inside_fields[j][2]
				excluded[cell_key(r, c)] = true
			end
			for j = 1, #nested.boundary_fields do
				local r, c = nested.boundary_fields[j][1], nested.boundary_fields[j][2]
				excluded[cell_key(r, c)] = true
			end
		end
	end
	local count = 0
	for i = 1, #wall.inside_fields do
		local r, c = wall.inside_fields[i][1], wall.inside_fields[i][2]
		if not excluded[cell_key(r, c)] then
			local cell = b[r][c]
			if not board.is_empty(cell) and cell.color == enemy_color then
				count = count + 1
			end
		end
	end
	return count
end

--- Stable dedupe key for an enclosure payout region.
--- @param wall table
--- @return string
function M.wall_region_key(wall)
	return wall.owner .. ":" .. boundary_signature(wall.boundary_fields)
end

function M.detect_regions_and_ownership(b, tiles)
	local n = config.BOARD_SIZE
	local regions = collect_empty_regions(b, tiles, n)
	local walls = M.extract_walls(b)
	local owner_map = assign_empty_owners_from_walls(walls)
	apply_region_owner_from_map(regions, owner_map)
	for id, region in pairs(regions) do
		region.boundary = collect_region_boundary_colors(b, n, region.tiles)
		if config.TERRITORY_DEBUG then
			print("[Territory] region", id, "size", region.size, "owner", tostring(region.owner))
		end
	end
	return regions
end

return M
