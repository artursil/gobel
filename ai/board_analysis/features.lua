--- Static board features for placement evaluation.
--- @module ai.board_analysis.features

local board = require("board")
local config = require("config")
local enclosure = require("single_game.resolver.enclosure")
local territory_analysis = require("ai.board_analysis.territory")

local M = {}

local ORTHO = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

--- @param b table
--- @param row integer
--- @param col integer
--- @param stone_color integer
--- @return integer
local function count_ortho_neighbors(b, row, col, stone_color)
	local n = config.BOARD_SIZE
	local count = 0
	for i = 1, #ORTHO do
		local nr, nc = row + ORTHO[i][1], col + ORTHO[i][2]
		if nr >= 1 and nr <= n and nc >= 1 and nc <= n then
			local cell = b[nr][nc]
			if not board.is_empty(cell) and cell.color == stone_color then
				count = count + 1
			end
		end
	end
	return count
end

--- Empty cell orthogonally adjacent to a stone of ``stone_color``.
--- @param b table
--- @param row integer
--- @param col integer
--- @param stone_color integer
--- @return boolean
function M.adjacent_to_own_stone(b, row, col, stone_color)
	return count_ortho_neighbors(b, row, col, stone_color) > 0
end

--- Empty intersection orthogonally adjacent to any cell in an own wall's ``boundary_fields``.
--- @param row integer
--- @param col integer
--- @param walls table
--- @param owner_key "B"|"W"
--- @return boolean
function M.is_on_my_wall_frontier(row, col, walls, owner_key)
	for i = 1, #walls do
		local wall = walls[i]
		if wall.owner == owner_key then
			for j = 1, #(wall.boundary_fields or {}) do
				local br, bc = wall.boundary_fields[j][1], wall.boundary_fields[j][2]
				for k = 1, #ORTHO do
					local nr, nc = br + ORTHO[k][1], bc + ORTHO[k][2]
					if nr == row and nc == col then
						return true
					end
				end
			end
		end
	end
	return false
end

--- Placement frontier: adjacent to own stone or on own wall frontier (single predicate; no double-count in scoring).
--- @param b table
--- @param row integer
--- @param col integer
--- @param stone_color integer
--- @param walls table|nil
--- @param owner_key "B"|"W"
--- @return boolean
function M.is_placement_frontier(b, row, col, stone_color, walls, owner_key)
	if not board.is_empty(b[row][col]) then
		return false
	end
	if M.adjacent_to_own_stone(b, row, col, stone_color) then
		return true
	end
	if walls then
		return M.is_on_my_wall_frontier(row, col, walls, owner_key)
	end
	return false
end

--- @param walls table
--- @param owner_key "B"|"W"
--- @return integer wall_count
--- @return integer largest_inside
local function wall_stats(walls, owner_key)
	local wall_count = 0
	local largest_inside = 0
	for i = 1, #walls do
		local wall = walls[i]
		if wall.owner == owner_key then
			wall_count = wall_count + 1
			local inside = wall.field_count or (wall.inside_fields and #wall.inside_fields) or 0
			if inside > largest_inside then
				largest_inside = inside
			end
		end
	end
	return wall_count, largest_inside
end

--- @param b table
--- @param stone_color integer
--- @param _owner_key "B"|"W"
--- @return integer
local function weak_boundary_cells(b, stone_color, _owner_key)
	local n = config.BOARD_SIZE
	local weak = 0
	for r = 1, n do
		for c = 1, n do
			if board.is_empty(b[r][c]) then
				if count_ortho_neighbors(b, r, c, stone_color) == 1 then
					weak = weak + 1
				end
			end
		end
	end
	return weak
end

--- @param b table
--- @param stone_color integer
--- @return number
local function connectivity_score(b, stone_color)
	local n = config.BOARD_SIZE
	local score = 0
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) and cell.color == stone_color then
				score = score + count_ortho_neighbors(b, r, c, stone_color)
			end
		end
	end
	return score
end

--- @param b table
--- @param _ko table|nil
--- @param owner_key "B"|"W"
--- @param territory_mode string|nil
--- @param stone_color integer
--- @param territory_counts table|nil cached ``territory_analysis.analyze`` result
--- @param walls table|nil cached ``enclosure.extract_walls`` (optional)
--- @return table
function M.build(b, _ko, owner_key, territory_mode, stone_color, territory_counts, walls)
	local counts = territory_counts or territory_analysis.analyze(b, territory_mode, owner_key)
	local wall_list = walls or enclosure.extract_walls(b)
	local wall_count_me, largest_inside = wall_stats(wall_list, owner_key)
	return {
		territory_owned_me = counts.owned_me,
		territory_owned_opp = counts.owned_opp,
		territory_contested = counts.contested,
		wall_count_me = wall_count_me,
		largest_enclosure_inside_me = largest_inside,
		weak_boundary_cells = weak_boundary_cells(b, stone_color, owner_key),
		connectivity_score_me = connectivity_score(b, stone_color),
		_territory_grid = counts.grid,
		_walls = wall_list,
	}
end

--- @param before table
--- @param after table
--- @return integer delta_me
--- @return integer delta_opp
function M.territory_delta(before, after)
	return (after.territory_owned_me or 0) - (before.territory_owned_me or 0),
		(after.territory_owned_opp or 0) - (before.territory_owned_opp or 0)
end

return M
