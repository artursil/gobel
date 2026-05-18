--- Dual PLACE suggestion: heuristic and match-score rankers over playable stones.
--- Merged pool entries: ``{ stone_id, row, col, heuristic_score, match_score }``.
--- Best pick: ``{ stone_id, row, col, score }``.
--- @module ai.candidates.dual_suggest

local ai_config = require("ai.config")
local enclosure = require("single_game.resolver.enclosure")
local features = require("ai.board_analysis.features")
local goals = require("ai.heuristics.goals")
local placement = require("ai.heuristics.placement")
local rules = require("rules")
local territory_analysis = require("ai.board_analysis.territory")

local M = {}

local placement_match_score = require("ai.scoring.placement_match_score")

--- @param stone_id string
--- @param row integer
--- @param col integer
--- @return string
function M.dedupe_key(stone_id, row, col)
	return stone_id .. ":" .. row .. ":" .. col
end

--- @param a table
--- @param b table
--- @return boolean
local function stable_before(a, b)
	if a.stone_id ~= b.stone_id then
		return a.stone_id < b.stone_id
	end
	if a.row ~= b.row then
		return a.row < b.row
	end
	return a.col < b.col
end

--- @param view table
--- @param max_stones integer
--- @return string[]
function M.enumerate_stones(view, max_stones)
	local playable = view:playable_stones()
	if max_stones <= 0 or max_stones >= #playable then
		return playable
	end
	local out = {}
	for i = 1, max_stones do
		out[i] = playable[i]
	end
	return out
end

--- @param view table
--- @param stone_id string
--- @param max_legal integer
--- @return table[]
function M.enumerate_legal_moves(view, stone_id, max_legal)
	local b = view:board()
	local legal = rules.all_legal_moves(b, view:stone_color(), view:ko_ban(), stone_id)
	local out = {}
	local n = #legal
	if max_legal > 0 and max_legal < n then
		n = max_legal
	end
	for i = 1, n do
		out[#out + 1] = { row = legal[i][1], col = legal[i][2] }
	end
	return out
end

--- @param entries table[]
--- @param n integer
--- @param get_score fun(entry: table): number|nil
--- @return table[]
function M.top_k(entries, n, get_score)
	if n <= 0 or #entries == 0 then
		return {}
	end
	local sorted = {}
	for i = 1, #entries do
		sorted[i] = entries[i]
	end
	table.sort(sorted, function(a, b)
		local sa = get_score(a)
		local sb = get_score(b)
		sa = sa or -math.huge
		sb = sb or -math.huge
		if sa ~= sb then
			return sa > sb
		end
		return stable_before(a, b)
	end)
	local out = {}
	local limit = math.min(n, #sorted)
	for i = 1, limit do
		out[#out + 1] = sorted[i]
	end
	return out
end

--- @param heuristic_top table[]
--- @param score_top table[]
--- @return table[]
function M.merge_ranked(heuristic_top, score_top)
	local map = {}
	local order = {}
	for i = 1, #heuristic_top do
		local e = heuristic_top[i]
		local key = M.dedupe_key(e.stone_id, e.row, e.col)
		if not map[key] then
			map[key] = {
				stone_id = e.stone_id,
				row = e.row,
				col = e.col,
				heuristic_score = e.heuristic_score,
				match_score = nil,
			}
			order[#order + 1] = key
		else
			map[key].heuristic_score = e.heuristic_score
		end
	end
	for i = 1, #score_top do
		local e = score_top[i]
		local key = M.dedupe_key(e.stone_id, e.row, e.col)
		if not map[key] then
			map[key] = {
				stone_id = e.stone_id,
				row = e.row,
				col = e.col,
				heuristic_score = nil,
				match_score = e.match_score,
			}
			order[#order + 1] = key
		else
			map[key].match_score = e.match_score
		end
	end
	local merged = {}
	for i = 1, #order do
		merged[#merged + 1] = map[order[i]]
	end
	return merged
end

--- @param view table
--- @param cache table
--- @param row integer
--- @param col integer
--- @param stone_id string
--- @param base table
--- @param territory_before table
--- @return table|nil
local function cached_evaluate(view, cache, row, col, stone_id, base, territory_before)
	local key = M.dedupe_key(stone_id, row, col)
	if cache[key] then
		return cache[key]
	end
	local scored = placement.evaluate_move(view, row, col, stone_id, base, territory_before)
	cache[key] = scored
	return scored
end

--- @param view table
--- @param suggestion table
--- @param base table
--- @param territory_before table
--- @param eval_cache table
--- @return table[]
--- @return table[]
local function rank_heuristic_and_score(view, suggestion, base, territory_before, eval_cache)
	local stones = M.enumerate_stones(view, suggestion.max_stones or 0)
	local heuristic_entries = {}
	local score_entries = {}
	for si = 1, #stones do
		local stone_id = stones[si]
		local moves = M.enumerate_legal_moves(view, stone_id, suggestion.max_legal_per_stone or 0)
		for mi = 1, #moves do
			local row, col = moves[mi].row, moves[mi].col
			local scored = cached_evaluate(view, eval_cache, row, col, stone_id, base, territory_before)
			if scored then
				heuristic_entries[#heuristic_entries + 1] = {
					stone_id = stone_id,
					row = row,
					col = col,
					heuristic_score = scored.score,
				}
			end
			local delta = placement_match_score.score_delta(view, stone_id, row, col)
			if delta ~= nil then
				score_entries[#score_entries + 1] = {
					stone_id = stone_id,
					row = row,
					col = col,
					match_score = delta,
				}
			end
		end
	end
	local heuristic_top = M.top_k(heuristic_entries, suggestion.n_heuristic or 0, function(e)
		return e.heuristic_score
	end)
	local score_top = M.top_k(score_entries, suggestion.n_score or 0, function(e)
		return e.match_score
	end)
	return heuristic_top, score_top
end

--- @param view table
--- @param merged table[]
--- @param base table
--- @param territory_before table
--- @param eval_cache table
--- @return table|nil
local function pick_best_merged(view, merged, base, territory_before, eval_cache)
	local best = nil
	local ties = {}
	for i = 1, #merged do
		local entry = merged[i]
		local scored = cached_evaluate(view, eval_cache, entry.row, entry.col, entry.stone_id, base, territory_before)
		if scored then
			local candidate = {
				stone_id = entry.stone_id,
				row = entry.row,
				col = entry.col,
				score = scored.score,
			}
			if not best or candidate.score > best.score then
				best = candidate
				ties = { candidate }
			elseif candidate.score == best.score then
				ties[#ties + 1] = candidate
			end
		end
	end
	if not best then
		return nil
	end
	if #ties == 1 then
		return best
	end
	table.sort(ties, stable_before)
	local pick = view:rng_next_int(#ties)
	return ties[pick]
end

--- @param view table
--- @return table|nil best { stone_id, row, col, score }
--- @return table[] merged
function M.choose_placement(view)
	local suggestion = ai_config.for_game(view:raw_game()).placement.suggestion
	if not suggestion then
		return nil, {}
	end
	local b = view:board()
	local mode = view:territory_mode()
	local owner_key = view:owner_key()
	local territory_before = territory_analysis.analyze(b, mode, owner_key)
	local walls = enclosure.extract_walls(b)
	local base = features.build(b, view:ko_ban(), owner_key, mode, view:stone_color(), territory_before, walls)
	goals.refresh(view, base, territory_before)
	local eval_cache = {}
	local heuristic_top, score_top = rank_heuristic_and_score(view, suggestion, base, territory_before, eval_cache)
	local merged = M.merge_ranked(heuristic_top, score_top)
	if #merged == 0 then
		return nil, merged
	end
	local best = pick_best_merged(view, merged, base, territory_before, eval_cache)
	return best, merged
end

return M
