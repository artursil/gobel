require("spec.test_helper")

local board = require("board")
local config = require("config")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local mcts = require("ai.search.mcts")
local rules = require("rules")
local spec_helper = require("spec.spec_helper")
local territory_analysis = require("ai.board_analysis.territory")

describe("ai.search.mcts dual stone pool", function()
	it("picks capture stone over dame with distinct stone_id arms", function()
		local rows = {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W W W . . .",
			". . . W B . . . .",
			". . . W W . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}
		local b = spec_helper.parse_board_ascii(rows)
		local g = match_state.new_match("pvc", nil, 5150)
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.ai_strategy = "heuristic"
		g.ai_mcts = {
			enabled = true,
			iterations = 60,
			max_rollout_depth = 3,
			exploration_c = 1.4,
			placement_tree_depth = 1,
		}
		g.board = b
		g.players.white.stones.playable_stones = { "stone_basic", "stone_focus" }
		g.players.white.stones.selected_stone = "stone_focus"
		local view = match_view.for_bot(g)
		local capture_row, capture_col
		for r = 1, config.BOARD_SIZE do
			for c = 1, config.BOARD_SIZE do
				if board.is_empty(b[r][c]) then
					local ok, _, _, captures = rules.try_play(b, r, c, config.STONE_WHITE, g.ko_ban, "stone_basic")
					if ok and captures > 0 and not capture_row then
						capture_row, capture_col = r, c
					end
				end
			end
		end
		assert.is_not_nil(capture_row)
		g.ai_scoring = { decision_mode = "absolute" }
		local merged = {
			{ stone_id = "stone_basic", row = capture_row, col = capture_col },
			{ stone_id = "stone_focus", row = 8, col = 8 },
		}
		local mode = view:territory_mode()
		local owner_key = view:owner_key()
		local territory_before = territory_analysis.analyze(b, mode, owner_key)
		local pick = mcts.choose_placement(view, merged, {
			territory_before = territory_before,
			enabled = true,
			iterations = 24,
			max_rollout_depth = 0,
			exploration_c = 0.5,
		})
		assert.is_not_nil(pick)
		assert.are.equal("stone_basic", pick.stone_id)
		assert.are.equal(capture_row, pick.row)
		assert.are.equal(capture_col, pick.col)
	end)
end)
