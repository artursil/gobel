--- Enclosure territory multiply target resolution for enclosure stones.
--- @module objects.effects_conditions.helpers.shared.enclosure_multiply_targets

local board = require("board")
local config = require("config")
local enclosure = require("single_game.resolver.enclosure")

local M = {}

local function cell_key(r, c)
	return r * 100 + c
end

local function inside_field_set(fields)
	local set = {}
	for i = 1, #fields do
		local field = fields[i]
		set[cell_key(field[1], field[2])] = true
	end
	return set
end

local function wall_contains_cell(wall, r, c)
	return inside_field_set(wall.inside_fields)[cell_key(r, c)] == true
end

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

local function stone_on_wall_boundary(wall, row, col)
	for i = 1, #wall.boundary_fields do
		local field = wall.boundary_fields[i]
		if field[1] == row and field[2] == col then
			return true
		end
	end
	return false
end

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

--- Resolve empty-cell keys whose territory_value should be multiplied for one enclosure stone.
function M.resolve_targets(walls, b, owner, row, col, stone_kind)
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

--- Filter multiply targets when the opponent also has an enclosure stone of the same kind.
function M.filter_by_region_owner(target_keys, state, owner, b, stone_kind)
	if opponent_has_enclosure_stone(b, stone_kind, owner) then
		return filter_targets_by_region_owner(target_keys, state, owner)
	end
	return target_keys
end

return M
