--- X/+ shape detection, tier scoring, and orthogonal wall groups.
--- @module game.patterns.shape_patterns

local board = require("board")
local config = require("config")
local rules = require("rules")

local M = {}

M.pattern_scoring = {
	x_tiers = { 5, 9, 13, 17, 21 },
	plus_tiers = { 5, 9, 13, 17, 21 },
	x_mult_per_tier = 2,
	plus_mult_per_tier = 5,
}

local DIAG_DIRS = {
	{ -1, -1 },
	{ -1, 1 },
	{ 1, -1 },
	{ 1, 1 },
}

local ORTHO_DIRS = {
	{ -1, 0 },
	{ 1, 0 },
	{ 0, -1 },
	{ 0, 1 },
}

--- @param count integer
--- @param thresholds integer[]
--- @return integer tier 0..#thresholds
local function tier_from_count(count, thresholds)
	local tier = 0
	for i = 1, #thresholds do
		if count >= thresholds[i] then
			tier = i
		end
	end
	return tier
end

--- @param b table
--- @param r integer
--- @param c integer
--- @return boolean
local function in_bounds(b, r, c)
	local n = config.BOARD_SIZE
	return r >= 1 and r <= n and c >= 1 and c <= n
end

--- @param b table
--- @param r integer
--- @param c integer
--- @param color integer
--- @return boolean
local function cell_matches_color(b, r, c, color)
	if not in_bounds(b, r, c) then
		return false
	end
	local cell = b[r][c]
	return not board.is_empty(cell) and cell.color == color
end

--- @param b table
--- @param cr integer
--- @param cc integer
--- @param color integer
--- @return boolean
local function diagonal_cross_filled(b, cr, cc, color)
	for i = 1, #DIAG_DIRS do
		local dr, dc = DIAG_DIRS[i][1], DIAG_DIRS[i][2]
		if not cell_matches_color(b, cr + dr, cc + dc, color) then
			return false
		end
	end
	return cell_matches_color(b, cr, cc, color)
end

--- @param b table
--- @param cr integer
--- @param cc integer
--- @param color integer
--- @return boolean
local function plus_cross_filled(b, cr, cc, color)
	for i = 1, #ORTHO_DIRS do
		local dr, dc = ORTHO_DIRS[i][1], ORTHO_DIRS[i][2]
		if not cell_matches_color(b, cr + dr, cc + dc, color) then
			return false
		end
	end
	return cell_matches_color(b, cr, cc, color)
end

--- @param b table
--- @param cr integer
--- @param cc integer
--- @param color integer
--- @param dirs table[]
--- @param marker_kind string|nil
--- @return table cells, integer count, boolean has_marker
local function collect_cross_cells(b, cr, cc, color, dirs, marker_kind)
	local seen = {}
	local cells = {}
	local function add(r, c)
		local key = r * 100 + c
		if seen[key] then
			return
		end
		if not cell_matches_color(b, r, c, color) then
			return
		end
		seen[key] = true
		cells[#cells + 1] = { r, c }
	end
	add(cr, cc)
	for i = 1, #dirs do
		local dr, dc = dirs[i][1], dirs[i][2]
		local r, c = cr + dr, cc + dc
		while cell_matches_color(b, r, c, color) do
			add(r, c)
			r, c = r + dr, c + dc
		end
	end
	local has_marker = false
	if marker_kind then
		for i = 1, #cells do
			local cell = b[cells[i][1]][cells[i][2]]
			if cell.kind == marker_kind then
				has_marker = true
				break
			end
		end
	end
	return cells, #cells, has_marker
end

--- @param b table
--- @param cr integer
--- @param cc integer
--- @param color integer
--- @return table cells, integer count, boolean has_x_stone
local function collect_x_cells(b, cr, cc, color)
	return collect_cross_cells(b, cr, cc, color, DIAG_DIRS, "x_stone")
end

--- @param b table
--- @param cr integer
--- @param cc integer
--- @param color integer
--- @return table cells, integer count, boolean has_plus_stone
local function collect_plus_cells(b, cr, cc, color)
	return collect_cross_cells(b, cr, cc, color, ORTHO_DIRS, "plus_stone")
end

--- @param list table[]
--- @param entry table
--- @return boolean
local function pattern_list_has_center(list, cr, cc)
	for i = 1, #list do
		if list[i].center_row == cr and list[i].center_col == cc then
			return true
		end
	end
	return false
end

--- @param b table
--- @param color integer
--- @return table[] { cells, tier, has_x_stone, center_row, center_col }
function M.detect_x_patterns(b, color)
	local n = config.BOARD_SIZE
	if n < 3 then
		return {}
	end
	local out = {}
	for cr = 2, n - 1 do
		for cc = 2, n - 1 do
			if diagonal_cross_filled(b, cr, cc, color) and not pattern_list_has_center(out, cr, cc) then
				local cells, count, has_x = collect_x_cells(b, cr, cc, color)
				local tier = tier_from_count(count, M.pattern_scoring.x_tiers)
				if tier > 0 then
					out[#out + 1] = {
						cells = cells,
						tier = tier,
						has_x_stone = has_x,
						center_row = cr,
						center_col = cc,
						stone_count = count,
					}
				end
			end
		end
	end
	return out
end

--- @param b table
--- @param color integer
--- @return table[] { cells, tier, has_plus_stone, center_row, center_col }
function M.detect_plus_patterns(b, color)
	local n = config.BOARD_SIZE
	if n < 3 then
		return {}
	end
	local out = {}
	for cr = 2, n - 1 do
		for cc = 2, n - 1 do
			if plus_cross_filled(b, cr, cc, color) and not pattern_list_has_center(out, cr, cc) then
				local cells, count, has_plus = collect_plus_cells(b, cr, cc, color)
				local tier = tier_from_count(count, M.pattern_scoring.plus_tiers)
				if tier > 0 then
					out[#out + 1] = {
						cells = cells,
						tier = tier,
						has_plus_stone = has_plus,
						center_row = cr,
						center_col = cc,
						stone_count = count,
					}
				end
			end
		end
	end
	return out
end

--- @param b table
--- @param row integer
--- @param col integer
--- @return table[] list of { row, col }
function M.group_connected(b, row, col)
	return rules.collect_group(b, row, col)
end

--- @param b table
--- @param group table[]
--- @return boolean
function M.group_has_wall_stone(b, group)
	for i = 1, #group do
		local r, c = group[i][1], group[i][2]
		local cell = b[r][c]
		if cell and cell.kind == "wall" then
			return true
		end
	end
	return false
end

--- @param tier integer
--- @return number multiplier factor (×2, ×4, ×8)
function M.x_mult_factor_for_tier(tier)
	local factor = 1
	for _ = 1, tier do
		factor = factor * M.pattern_scoring.x_mult_per_tier
	end
	return factor
end

--- @param pattern table
--- @param b table
--- @return integer
function M.count_x_stones_in_pattern(b, pattern)
	local n = 0
	for i = 1, #pattern.cells do
		local r, c = pattern.cells[i][1], pattern.cells[i][2]
		local cell = b[r][c]
		if cell and cell.kind == "x_stone" then
			n = n + 1
		end
	end
	return n
end

--- @param x_stone_count integer
--- @return number product of ×2 per ``x_stone`` in the completed X
function M.x_mult_factor_for_x_stone_count(x_stone_count)
	local factor = 1
	for _ = 1, x_stone_count do
		factor = factor * M.pattern_scoring.x_mult_per_tier
	end
	return factor
end

--- @param patterns table[]
--- @return table<string, integer>
local function tier_by_center(patterns)
	local map = {}
	for i = 1, #patterns do
		local p = patterns[i]
		map[p.center_row .. ":" .. p.center_col] = p.tier
	end
	return map
end

--- X patterns whose tier increased after a placement (new completion or larger X: 5→9, …).
--- @param b_before table board without the stone just played
--- @param b_after table
--- @param color integer
--- @return table[] subset of ``detect_x_patterns`` results on ``b_after``
function M.detect_newly_completed_x_patterns(b_before, b_after, color)
	local before_tiers = tier_by_center(M.detect_x_patterns(b_before, color))
	local after_patterns = M.detect_x_patterns(b_after, color)
	local out = {}
	for i = 1, #after_patterns do
		local p = after_patterns[i]
		local prev = before_tiers[p.center_row .. ":" .. p.center_col] or 0
		if p.tier > prev then
			out[#out + 1] = p
		end
	end
	return out
end

--- @param pattern table
--- @param b table
--- @return integer
function M.count_plus_stones_in_pattern(b, pattern)
	local n = 0
	for i = 1, #pattern.cells do
		local r, c = pattern.cells[i][1], pattern.cells[i][2]
		local cell = b[r][c]
		if cell and cell.kind == "plus_stone" then
			n = n + 1
		end
	end
	return n
end

--- @param plus_stone_count integer
--- @return integer additive plus_mult bonus (+5 per ``plus_stone`` in the completed +)
function M.plus_mult_bonus_for_plus_stone_count(plus_stone_count)
	return plus_stone_count * M.pattern_scoring.plus_mult_per_tier
end

--- + patterns whose tier increased after a placement (new completion or larger +: 5→9, …).
--- @param b_before table board without the stone just played
--- @param b_after table
--- @param color integer
--- @return table[] subset of ``detect_plus_patterns`` results on ``b_after``
function M.detect_newly_completed_plus_patterns(b_before, b_after, color)
	local before_tiers = tier_by_center(M.detect_plus_patterns(b_before, color))
	local after_patterns = M.detect_plus_patterns(b_after, color)
	local out = {}
	for i = 1, #after_patterns do
		local p = after_patterns[i]
		local prev = before_tiers[p.center_row .. ":" .. p.center_col] or 0
		if p.tier > prev then
			out[#out + 1] = p
		end
	end
	return out
end

--- @param tier integer
--- @return integer plus_mult bonus total
function M.plus_mult_bonus_for_tier(tier)
	return tier * M.pattern_scoring.plus_mult_per_tier
end

return M
