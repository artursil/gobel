require("spec.test_helper")

local board = require("board")
local config = require("config")
local evaluate = require("ai.board_analysis.evaluate")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local mcts = require("ai.search.mcts")
local spec_helper = require("spec.spec_helper")
local territory_analysis = require("ai.board_analysis.territory")

local function place_phase_view(seed)
	local g = match_state.new_match("pvc", nil, seed)
	g.phase = "PLACE_PHASE"
	g.to_play = "white"
	g.players.white.stones.selected_stone = "stone_basic"
	g.ai_strategy = "heuristic"
	g.ai_mcts = {
		enabled = true,
		iterations = 40,
		max_rollout_depth = 4,
		exploration_c = 1.4,
	}
	return match_view.for_bot(g)
end

describe("ai.board_analysis.evaluate", function()
	it("score increases when owner gains empty territory", function()
		local rows_before = {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}
		local rows_after = {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}
		local b0 = spec_helper.parse_board_ascii(rows_before)
		local b1 = spec_helper.parse_board_ascii(rows_after)
		local mode = "regional"
		local white = config.STONE_WHITE
		local before = evaluate.evaluate_position(b0, nil, "W", mode, white, nil, nil, nil)
		local after = evaluate.evaluate_position(b1, nil, "W", mode, white, nil, nil, nil)
		assert.is_true(after > before)
	end)
end)

describe("ai.search.mcts", function()
	it("returns nil when MCTS disabled", function()
		local g = match_state.new_match("pvc", nil, 99)
		g.ai_strategy = "heuristic"
		g.ai_mcts = { enabled = false, iterations = 80 }
		local view = match_view.for_bot(g)
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.players.white.stones.selected_stone = "stone_basic"
		local pick = mcts.choose_placement(view, { { row = 3, col = 3 } }, g.ai_mcts)
		assert.is_nil(pick)
	end)

	it("chooses same move for identical seed and board", function()
		local rows = {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}
		local b = spec_helper.parse_board_ascii(rows)
		local candidates = {
			{ row = 3, col = 3 },
			{ row = 5, col = 5 },
			{ row = 7, col = 7 },
		}
		local function run_once(seed)
			local view = place_phase_view(seed)
			view:raw_game().board = b
			local mode = view:territory_mode()
			local owner_key = view:owner_key()
			local territory_before = territory_analysis.analyze(b, mode, owner_key)
			return mcts.choose_placement(view, candidates, {
				territory_before = territory_before,
				enabled = true,
				iterations = 12,
				max_rollout_depth = 2,
				exploration_c = 1.4,
			})
		end
		local a = run_once(4242)
		local b_pick = run_once(4242)
		assert.is_not_nil(a)
		assert.is_not_nil(b_pick)
		assert.are.equal(a.row, b_pick.row)
		assert.are.equal(a.col, b_pick.col)
	end)
end)
