--- Live score: territory points × overall multiplier; X-kind stones inside diagonal crosses add to mult.

local board = require("board")
local config = require("config")
local patterns = require("patterns")
local stone_kinds = require("stone_kinds")

local M = {}

local BASE_MULT = 1

local function center_distance(row, col)
	local center = (config.BOARD_SIZE + 1) * 0.5
	return math.abs(row - center) + math.abs(col - center)
end

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

local function quarters_overlap(a, b)
	for q = 1, 4 do
		if a[q] and b[q] then
			return true
		end
	end
	return false
end

local function nearest_corner(row, col)
	local n = config.BOARD_SIZE
	local corner_row = (row - 1) <= (n - row) and 1 or n
	local corner_col = (col - 1) <= (n - col) and 1 or n
	return corner_row, corner_col
end

local function in_stone_corner_region(stone, row, col)
	return row >= stone.min_row and row <= stone.max_row and col >= stone.min_col and col <= stone.max_col
end

local function is_outside_candidate(stone, row, col, point_quarter, point_center_dist)
	local same_quarter = quarters_overlap(stone.quarter, point_quarter)
	local within_corner_region = in_stone_corner_region(stone, row, col)
	return same_quarter and stone.center_dist <= point_center_dist and within_corner_region
end

local function neighbors(row, col, n)
	local out = {}
	if row > 1 then
		out[#out + 1] = { row - 1, col }
	end
	if row < n then
		out[#out + 1] = { row + 1, col }
	end
	if col > 1 then
		out[#out + 1] = { row, col - 1 }
	end
	if col < n then
		out[#out + 1] = { row, col + 1 }
	end
	return out
end

local function enclosed_claim_map(b, wall_color)
	local n = config.BOARD_SIZE
	local claim = {}
	local claim_size = {}
	local visited = {}
	for r = 1, n do
		claim[r] = {}
		claim_size[r] = {}
		visited[r] = {}
		for c = 1, n do
			claim[r][c] = false
			claim_size[r][c] = math.huge
			visited[r][c] = false
		end
	end
	for r = 1, n do
		for c = 1, n do
			if not visited[r][c] and board.is_empty(b[r][c]) then
				local queue = { { r, c } }
				local head = 1
				visited[r][c] = true
				local cells = {}
				local touches_top = false
				local touches_bottom = false
				local touches_left = false
				local touches_right = false
				local min_row = r
				local max_row = r
				local min_col = c
				local max_col = c
				local touches_opponent_stone = false
				while head <= #queue do
					local cell = queue[head]
					head = head + 1
					local cr, cc = cell[1], cell[2]
					cells[#cells + 1] = { cr, cc }
					if cr == 1 then
						touches_top = true
					end
					if cr == n then
						touches_bottom = true
					end
					if cc == 1 then
						touches_left = true
					end
					if cc == n then
						touches_right = true
					end
					if cr < min_row then
						min_row = cr
					end
					if cr > max_row then
						max_row = cr
					end
					if cc < min_col then
						min_col = cc
					end
					if cc > max_col then
						max_col = cc
					end
					local ns = neighbors(cr, cc, n)
					for i = 1, #ns do
						local nr, nc = ns[i][1], ns[i][2]
						local neighbor_cell = b[nr][nc]
						local neighbor_color = board.chain_color(neighbor_cell)
						if neighbor_color ~= config.STONE_NONE and neighbor_color ~= wall_color then
							touches_opponent_stone = true
						end
						if not visited[nr][nc] and board.is_empty(neighbor_cell) then
							visited[nr][nc] = true
							queue[#queue + 1] = { nr, nc }
						end
					end
				end
				local touches_count = 0
				if touches_top then
					touches_count = touches_count + 1
				end
				if touches_bottom then
					touches_count = touches_count + 1
				end
				if touches_left then
					touches_count = touches_count + 1
				end
				if touches_right then
					touches_count = touches_count + 1
				end

				local function row_is_wall(row, c0, c1)
					if row < 1 or row > n then
						return false
					end
					for cc = c0, c1 do
						if board.chain_color(b[row][cc]) ~= wall_color then
							return false
						end
					end
					return true
				end

				local function col_is_wall(col, r0, r1)
					if col < 1 or col > n then
						return false
					end
					for rr = r0, r1 do
						if board.chain_color(b[rr][col]) ~= wall_color then
							return false
						end
					end
					return true
				end

				local enclosed = false
				if touches_count == 0 then
					enclosed = true
				elseif touches_count == 2 then
					if touches_left and touches_bottom then
						enclosed = row_is_wall(min_row - 1, min_col, max_col) and col_is_wall(max_col + 1, min_row, max_row)
					elseif touches_left and touches_top then
						enclosed = row_is_wall(max_row + 1, min_col, max_col) and col_is_wall(max_col + 1, min_row, max_row)
					elseif touches_right and touches_bottom then
						enclosed = row_is_wall(min_row - 1, min_col, max_col) and col_is_wall(min_col - 1, min_row, max_row)
					elseif touches_right and touches_top then
						enclosed = row_is_wall(max_row + 1, min_col, max_col) and col_is_wall(min_col - 1, min_row, max_row)
					end
				end

				if enclosed and not touches_opponent_stone then
					local size = #cells
					for i = 1, #cells do
						local cr, cc = cells[i][1], cells[i][2]
						if board.is_empty(b[cr][cc]) then
							claim[cr][cc] = true
							claim_size[cr][cc] = size
						end
					end
				end
			end
		end
	end
	return claim, claim_size
end

local function territory_map_distance_only(b)
	local n = config.BOARD_SIZE
	local stones = {}
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				stones[#stones + 1] = {
					row = r,
					col = c,
					color = cell.color,
				}
			end
		end
	end
	local out = {}
	for r = 1, n do
		out[r] = {}
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				out[r][c] = cell.color
			else
				local min_dist = nil
				local black_hits = 0
				local white_hits = 0
				for i = 1, #stones do
					local s = stones[i]
					local d = math.abs(r - s.row) + math.abs(c - s.col)
					if not min_dist or d < min_dist then
						min_dist = d
						black_hits = 0
						white_hits = 0
					end
					if d == min_dist then
						if s.color == config.STONE_BLACK then
							black_hits = black_hits + 1
						elseif s.color == config.STONE_WHITE then
							white_hits = white_hits + 1
						end
					end
				end
				if min_dist and black_hits > white_hits then
					out[r][c] = config.STONE_BLACK
				elseif min_dist and white_hits > black_hits then
					out[r][c] = config.STONE_WHITE
				else
					out[r][c] = config.STONE_NONE
				end
			end
		end
	end
	return out
end

local function territory_map_regional(b)
	local n = config.BOARD_SIZE
	local stones = {}
	local nearest_tie = {}
	for r = 1, n do
		nearest_tie[r] = {}
		for c = 1, n do
			nearest_tie[r][c] = false
		end
	end
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				local corner_row, corner_col = nearest_corner(r, c)
				stones[#stones + 1] = {
					row = r,
					col = c,
					color = cell.color,
					center_dist = center_distance(r, c),
					quarter = board_quarter(r, c),
					min_row = math.min(r, corner_row),
					max_row = math.max(r, corner_row),
					min_col = math.min(c, corner_col),
					max_col = math.max(c, corner_col),
				}
			end
		end
	end
	local out = {}
	for r = 1, n do
		out[r] = {}
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				out[r][c] = cell.color
			else
				local point_center_dist = center_distance(r, c)
				local point_quarter = board_quarter(r, c)
				local global_min = nil
				local global_black_hits = 0
				local global_white_hits = 0
				for i = 1, #stones do
					local s = stones[i]
					if is_outside_candidate(s, r, c, point_quarter, point_center_dist) then
						local d = math.abs(r - s.row) + math.abs(c - s.col)
						if not global_min or d < global_min then
							global_min = d
							global_black_hits = 0
							global_white_hits = 0
						end
						if d == global_min then
							if s.color == config.STONE_BLACK then
								global_black_hits = global_black_hits + 1
							elseif s.color == config.STONE_WHITE then
								global_white_hits = global_white_hits + 1
							end
						end
					end
				end
				if global_min and global_black_hits == global_white_hits and (global_black_hits + global_white_hits) > 0 then
					out[r][c] = config.STONE_NONE
					nearest_tie[r][c] = true
				else
				local min_dist = nil
				local black_hits = 0
				local white_hits = 0
				for i = 1, #stones do
					local s = stones[i]
					if is_outside_candidate(s, r, c, point_quarter, point_center_dist) then
						local d = math.abs(r - s.row) + math.abs(c - s.col)
						if not min_dist or d < min_dist then
							min_dist = d
							black_hits = 0
							white_hits = 0
						end
						if d == min_dist then
							if s.color == config.STONE_BLACK then
								black_hits = black_hits + 1
							elseif s.color == config.STONE_WHITE then
								white_hits = white_hits + 1
							end
						end
					end
				end
				if min_dist and black_hits > white_hits then
					out[r][c] = config.STONE_BLACK
				elseif min_dist and white_hits > black_hits then
					out[r][c] = config.STONE_WHITE
				else
					out[r][c] = config.STONE_NONE
				end
				end
			end
		end
	end
	local black_claim, black_claim_size = enclosed_claim_map(b, config.STONE_BLACK)
	local white_claim, white_claim_size = enclosed_claim_map(b, config.STONE_WHITE)
	for r = 1, n do
		for c = 1, n do
			if board.is_empty(b[r][c]) then
				local b_claim = black_claim[r][c]
				local w_claim = white_claim[r][c]
				if nearest_tie[r][c] then
					if b_claim and not w_claim then
						out[r][c] = config.STONE_BLACK
					elseif w_claim and not b_claim then
						out[r][c] = config.STONE_WHITE
					elseif b_claim and w_claim then
						if black_claim_size[r][c] < white_claim_size[r][c] then
							out[r][c] = config.STONE_BLACK
						elseif white_claim_size[r][c] < black_claim_size[r][c] then
							out[r][c] = config.STONE_WHITE
						end
					else
						out[r][c] = config.STONE_NONE
					end
				elseif b_claim and not w_claim then
					out[r][c] = config.STONE_BLACK
				elseif w_claim and not b_claim then
					out[r][c] = config.STONE_WHITE
				elseif b_claim and w_claim then
					if black_claim_size[r][c] < white_claim_size[r][c] then
						out[r][c] = config.STONE_BLACK
					elseif white_claim_size[r][c] < black_claim_size[r][c] then
						out[r][c] = config.STONE_WHITE
					end
				end
			end
		end
	end
	return out
end

function M.territory_map(b, territory_mode)
	if territory_mode == "distance_only" then
		return territory_map_distance_only(b)
	end
	return territory_map_regional(b)
end

function M.territory_points(territory, color)
	local n = config.BOARD_SIZE
	local count = 0
	for r = 1, n do
		for c = 1, n do
			if territory[r][c] == color then
				count = count + 1
			end
		end
	end
	return count
end

--- Territory-backed points for compatibility with existing call sites.
--- @param b table
--- @param color integer
--- @param territory_mode string|nil
--- @return integer
function M.liberty_points(b, color, territory_mode)
	local territory = M.territory_map(b, territory_mode)
	return M.territory_points(territory, color)
end

--- Sum of (X-kind hits across all complete crosses, counting overlaps) × bonus constant, added to base mult.
--- @param b table
--- @param color integer
--- @return integer
function M.mult_bonus_from_patterns(b, color)
	local nx = patterns.count_x_stones_in_diagonal_patterns(b, color)
	return nx * stone_kinds.MULT_BONUS_PER_DIAGONAL_X_PATTERN
end

--- Overall multiplier: base plus pattern-linked X stone bonus.
--- @param b table
--- @param color integer
--- @return integer
function M.overall_mult(b, color)
	return BASE_MULT + M.mult_bonus_from_patterns(b, color)
end

--- Total score used in the UI and for comparisons.
--- @param b table
--- @param color integer
--- @return integer
function M.total_score(b, color)
	return M.liberty_points(b, color) * M.overall_mult(b, color)
end

return M
