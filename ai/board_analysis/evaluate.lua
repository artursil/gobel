--- Static position evaluation for MCTS rollouts (no per-move deltas, no resolve_round).
---
--- Weights (tune here):
--- | Feature | Weight | Notes |
--- |---------|--------|-------|
--- | territory_owned_me - territory_owned_opp | 3.0 | empty-cell control margin |
--- | largest_enclosure_inside_me | 1.5 | enclosure size |
--- | wall_count_me | 0.5 | number of own walls |
--- | territory_contested | -2.0 | penalty per contested empty |
--- | weak_boundary_cells | -0.3 | fragile frontier count |
--- @module ai.board_analysis.evaluate

local board = require("board")
local config = require("config")
local features = require("ai.board_analysis.features")
local goals = require("ai.heuristics.goals")

local M = {}

M.FAST_WEIGHTS = {
	stone_diff = 2.0,
	largest_enclosure = 1.2,
	wall_count = 0.4,
}

M.WEIGHTS = {
	territory_diff = 3.0,
	largest_enclosure = 1.5,
	wall_count = 0.5,
	contested_penalty = -2.0,
	weak_boundary = -0.3,
}

--- @param b table
--- @param ko table|nil
--- @param owner_key "B"|"W"
--- @param territory_mode string|nil
--- @param stone_color integer
--- @param walls table|nil
--- @param territory_counts table|nil
--- @param game table|nil for goals.position_bonus
--- @return number higher = better for owner_key
function M.evaluate_position(b, ko, owner_key, territory_mode, stone_color, walls, territory_counts, game)
	local feat = features.build(b, ko, owner_key, territory_mode, stone_color, territory_counts, walls)
	local w = M.WEIGHTS
	local score = 0
	score = score + w.territory_diff * (feat.territory_owned_me - feat.territory_owned_opp)
	score = score + w.largest_enclosure * feat.largest_enclosure_inside_me
	score = score + w.wall_count * feat.wall_count_me
	score = score + w.contested_penalty * feat.territory_contested
	score = score + w.weak_boundary * feat.weak_boundary_cells
	if game then
		score = score + goals.position_bonus(game, feat)
	end
	return score
end

--- @param ai_score number
--- @param opp_score number
--- @return number normalized in [0, 1] for backprop
function M.normalize_result(ai_score, opp_score)
	local margin = ai_score - opp_score
	return math.max(0, math.min(1, 0.5 + margin / 40))
end

--- Cheap static eval for MCTS rollouts (no ``compute_from_board``).
--- @param b table
--- @param stone_color integer
--- @param owner_key "B"|"W"
--- @param walls table|nil
--- @return number
function M.fast_evaluate_position(b, stone_color, owner_key, walls)
	local n = config.BOARD_SIZE
	local opp_color = stone_color == config.STONE_BLACK and config.STONE_WHITE or config.STONE_BLACK
	local me_stones = 0
	local opp_stones = 0
	for r = 1, n do
		for c = 1, n do
			local cell = b[r][c]
			if not board.is_empty(cell) then
				if cell.color == stone_color then
					me_stones = me_stones + 1
				elseif cell.color == opp_color then
					opp_stones = opp_stones + 1
				end
			end
		end
	end
	local largest = 0
	local wall_count = 0
	if walls then
		for i = 1, #walls do
			local wall = walls[i]
			if wall.owner == owner_key then
				wall_count = wall_count + 1
				local inside = wall.field_count or (wall.inside_fields and #wall.inside_fields) or 0
				if inside > largest then
					largest = inside
				end
			end
		end
	end
	local w = M.FAST_WEIGHTS
	return w.stone_diff * (me_stones - opp_stones) + w.largest_enclosure * largest + w.wall_count * wall_count
end

return M
