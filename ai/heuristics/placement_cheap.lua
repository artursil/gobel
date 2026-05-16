--- Fast placement prescore (no territory assignment). Used before full ``evaluate_move``.
--- @module ai.heuristics.placement_cheap

local features = require("ai.board_analysis.features")
local rules = require("rules")

local M = {}

--- @param view table
--- @param row integer
--- @param col integer
--- @param stone_id string
--- @param walls table|nil
--- @return number|nil
function M.score(view, row, col, stone_id, walls)
	local b = view:board()
	local player = view:stone_color()
	local owner_key = view:owner_key()
	local ok, _, _, captures = rules.try_play(b, row, col, player, view:ko_ban(), stone_id)
	if not ok then
		return nil
	end
	local score = captures * 100
	if features.is_placement_frontier(b, row, col, player, walls, owner_key) then
		score = score + 15
	end
	return score
end

--- @param view table
--- @param candidates table[]
--- @param stone_id string
--- @param walls table|nil
--- @param top_n integer
--- @return table[] subset of candidates
function M.top_by_cheap_score(view, candidates, stone_id, walls, top_n)
	local scored = {}
	for i = 1, #candidates do
		local move = candidates[i]
		local s = M.score(view, move.row, move.col, stone_id, walls)
		if s then
			scored[#scored + 1] = { row = move.row, col = move.col, cheap_score = s }
		end
	end
	table.sort(scored, function(a, b)
		return a.cheap_score > b.cheap_score
	end)
	local out = {}
	local n = math.min(top_n, #scored)
	for i = 1, n do
		out[#out + 1] = { row = scored[i].row, col = scored[i].col }
	end
	return out
end

return M
