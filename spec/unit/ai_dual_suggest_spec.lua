require("spec.test_helper")

local ai_config = require("ai.config")
local board = require("board")
local config = require("config")
local dual_suggest = require("ai.candidates.dual_suggest")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local rules = require("rules")
local spec_helper = require("spec.spec_helper")

local saved_match_score_module

local function enable_suggestion(g, overrides)
	ai_config.apply_profile(g, "normal")
	g.phase = "PLACE_PHASE"
	g.to_play = "white"
	g.ai_placement = g.ai_placement or {}
	g.ai_placement.suggestion = {
		enabled = true,
		stone_only_main = true,
		n_heuristic = 8,
		n_score = 8,
		max_stones = 0,
		max_legal_per_stone = 0,
	}
	if overrides then
		for k, v in pairs(overrides) do
			g.ai_placement.suggestion[k] = v
		end
	end
end

local function view_for_game(g)
	g.players.white.stones.selected_stone = g.players.white.stones.playable_stones[1]
	g.players.white.stones.selected_stone_index = 1
	return match_view.for_bot(g)
end

describe("ai.candidates.dual_suggest", function()
	local saved_mcts_module

	after_each(function()
		package.loaded["ai.scoring.placement_match_score"] = saved_match_score_module
		package.loaded["ai.search.mcts"] = saved_mcts_module
		package.loaded["ai.candidates.dual_suggest"] = nil
	end)

	it("merge_ranked dedupes overlapping entries", function()
		local heuristic_top = {
			{ stone_id = "stone_basic", row = 5, col = 5, heuristic_score = 10 },
			{ stone_id = "stone_basic", row = 3, col = 3, heuristic_score = 5 },
		}
		local score_top = {
			{ stone_id = "stone_basic", row = 5, col = 5, match_score = 99 },
			{ stone_id = "stone_focus", row = 1, col = 1, match_score = 50 },
		}
		local merged = dual_suggest.merge_ranked(heuristic_top, score_top)
		assert.are.equal(3, #merged)
		local found_overlap = false
		for i = 1, #merged do
			local e = merged[i]
			if e.row == 5 and e.col == 5 and e.stone_id == "stone_basic" then
				found_overlap = true
				assert.are.equal(10, e.heuristic_score)
				assert.are.equal(99, e.match_score)
			end
		end
		assert.is_true(found_overlap)
	end)

	it("n_score zero still picks from heuristic ranker", function()
		local g = match_state.new_match("pvc")
		enable_suggestion(g, { n_heuristic = 4, n_score = 0 })
		g.board = board.new()
		local view = view_for_game(g)
		local best, merged = dual_suggest.choose_placement(view)
		assert.is_not_nil(best)
		assert.is_true(#merged >= 1)
		assert.is_not_nil(best.stone_id)
		assert.is_not_nil(best.row)
		assert.is_not_nil(best.col)
		assert.is_number(best.score)
		local ok = select(1, rules.try_play(g.board, best.row, best.col, config.STONE_WHITE, g.ko_ban, best.stone_id))
		assert.is_true(ok)
	end)

	it("honors max_stones cap", function()
		local g = match_state.new_match("pvc")
		enable_suggestion(g, { n_heuristic = 81, n_score = 0, max_stones = 1, max_legal_per_stone = 0 })
		g.players.white.stones.playable_stones = { "stone_basic", "stone_focus", "stone_special" }
		g.board = board.new()
		local view = view_for_game(g)
		local stones = dual_suggest.enumerate_stones(view, 1)
		assert.are.equal(1, #stones)
		assert.are.equal("stone_basic", stones[1])
		local best = dual_suggest.choose_placement(view)
		assert.are.equal("stone_basic", best.stone_id)
	end)

	it("honors max_legal_per_stone cap", function()
		local g = match_state.new_match("pvc")
		enable_suggestion(g, { n_heuristic = 81, n_score = 0, max_stones = 0, max_legal_per_stone = 1 })
		g.board = board.new()
		local view = view_for_game(g)
		local stone_id = g.players.white.stones.playable_stones[1]
		local all_legal = rules.all_legal_moves(g.board, config.STONE_WHITE, g.ko_ban, stone_id)
		assert.is_true(#all_legal > 1)
		local capped = dual_suggest.enumerate_legal_moves(view, stone_id, 1)
		assert.are.equal(1, #capped)
		assert.are.equal(all_legal[1][1], capped[1].row)
		assert.are.equal(all_legal[1][2], capped[1].col)
	end)

	it("choose_placement uses MCTS pick when enabled", function()
		saved_mcts_module = package.loaded["ai.search.mcts"]
		package.loaded["ai.search.mcts"] = {
			choose_placement = function()
				return { row = 1, col = 1, stone_id = "stone_focus" }
			end,
		}
		package.loaded["ai.candidates.dual_suggest"] = nil
		local suggest = require("ai.candidates.dual_suggest")
		local g = match_state.new_match("pvc")
		enable_suggestion(g, { n_heuristic = 4, n_score = 4 })
		g.players.white.stones.playable_stones = { "stone_basic", "stone_focus" }
		g.ai_mcts = { enabled = true, iterations = 8, placement_tree_depth = 1, max_rollout_depth = 2 }
		g.board = spec_helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W W W . . .",
			". . . W B . . . .",
			". . . W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local view = view_for_game(g)
		local best = suggest.choose_placement(view)
		assert.is_not_nil(best)
		assert.are.equal(1, best.row)
		assert.are.equal(1, best.col)
		assert.are.equal("stone_focus", best.stone_id)
	end)

	it("choose_placement returns merged pool with expected fields", function()
		saved_match_score_module = package.loaded["ai.scoring.placement_match_score"]
		package.loaded["ai.scoring.placement_match_score"] = {
			score_delta = function(_view, _stone_id, row, col)
				if row == 5 and col == 5 then
					return 1000
				end
				return 0
			end,
		}
		package.loaded["ai.candidates.dual_suggest"] = nil
		local suggest = require("ai.candidates.dual_suggest")
		local g = match_state.new_match("pvc")
		enable_suggestion(g, { n_heuristic = 4, n_score = 4 })
		g.board = spec_helper.parse_board_ascii({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W W W . . .",
			". . . W B . . . .",
			". . . W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		})
		local view = view_for_game(g)
		local best, merged = suggest.choose_placement(view)
		assert.is_not_nil(best)
		assert.is_true(#merged >= 1)
		for i = 1, #merged do
			local e = merged[i]
			assert.is_string(e.stone_id)
			assert.is_number(e.row)
			assert.is_number(e.col)
		end
	end)
end)
