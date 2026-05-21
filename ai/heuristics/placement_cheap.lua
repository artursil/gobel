--- Fast placement prescore via ``stone_heuristics_def.sum_pre_selection`` (no full selection eval).
--- @module ai.heuristics.placement_cheap

local ai_config = require("ai.config")
local enclosure = require("single_game.resolver.enclosure")
local placement_context = require("ai.heuristics.placement_context")
local rules = require("rules")
local stone_heuristics_def = require("ai.heuristics.stone_heuristics_def")
local territory_analysis = require("ai.board_analysis.territory")

local M = {}

--- @param view table
--- @param row integer
--- @param col integer
--- @param stone_id string
--- @param walls table|nil
--- @param territory_before table|nil
--- @return number|nil
function M.score(view, row, col, stone_id, walls, territory_before)
	local ctx = placement_context.build(view, row, col, stone_id, nil, territory_before)
	if not ctx then
		return nil
	end
	local placement_cfg = ai_config.for_game(view:raw_game()).placement
	return stone_heuristics_def.sum_pre_selection(ctx, placement_cfg)
end

--- @param view table
--- @param candidates table[]
--- @param stone_id string
--- @param walls table|nil
--- @param top_n integer
--- @return table[] subset of candidates
function M.top_by_cheap_score(view, candidates, stone_id, walls, top_n)
	local b = view:board()
	local mode = view:territory_mode()
	local owner_key = view:owner_key()
	territory_before = territory_analysis.analyze(b, mode, owner_key)
	walls = walls or enclosure.extract_walls(b)
	local scored = {}
	for i = 1, #candidates do
		local move = candidates[i]
		local s = M.score(view, move.row, move.col, stone_id, walls, territory_before)
		if s then
			scored[#scored + 1] = { row = move.row, col = move.col, cheap_score = s }
		end
	end
	table.sort(scored, function(a, b_entry)
		return a.cheap_score > b_entry.cheap_score
	end)
	local out = {}
	local n = math.min(top_n, #scored)
	for i = 1, n do
		out[#out + 1] = { row = scored[i].row, col = scored[i].col }
	end
	return out
end

--- Best cheap prescore on legal moves (no territory assignment).
--- @param view table
--- @param stone_id string
--- @param walls table|nil
--- @return number
function M.best_placement_score(view, stone_id, walls)
	local b = view:board()
	local legal = rules.all_legal_moves(b, view:stone_color(), view:ko_ban(), stone_id)
	walls = walls or enclosure.extract_walls(b)
	local best = 0
	for i = 1, #legal do
		local row, col = legal[i][1], legal[i][2]
		local s = M.score(view, row, col, stone_id, walls, nil)
		if s and s > best then
			best = s
		end
	end
	return best * 0.01
end

return M
