require("spec.test_helper")

local board = require("board")
local features = require("ai.board_analysis.features")
local goals = require("ai.heuristics.goals")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local spec_helper = require("spec.spec_helper")
local territory_analysis = require("ai.board_analysis.territory")

describe("ai.heuristics.goals", function()
	after_each(function()
		goals._test_bonus = nil
	end)

	it("refresh activates expand_enclosure and claim_contested from base features", function()
		local g = match_state.new_match("pvc")
		g.board = board.new()
		local view = match_view.for_bot(g)
		local mode = view:territory_mode()
		local owner_key = view:owner_key()
		local territory_before = territory_analysis.analyze(g.board, mode, owner_key)
		local base = {
			largest_enclosure_inside_me = 2,
			territory_contested = 1,
		}
		goals.refresh(view, base, territory_before)
		assert.is_not_nil(g.ai_goals)
		assert.are.equal(2, #g.ai_goals)
		local ids = {}
		for i = 1, #g.ai_goals do
			ids[g.ai_goals[i].id] = true
		end
		assert.is_true(ids.expand_enclosure)
		assert.is_true(ids.claim_contested)
	end)

	it("candidate_bonus is non-zero when active goal matches candidate", function()
		local g = match_state.new_match("pvc")
		g.ai_goals = { { id = "claim_contested", weight = 3 } }
		local view = match_view.for_bot(g)
		local bonus = goals.candidate_bonus(view, { delta_territory_me = 1 })
		assert.are.equal(3, bonus)
	end)

	it("refresh activates cut_connectivity when a capture is legal", function()
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
		local g = match_state.new_match("pvc")
		g.board = b
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.players.white.stones.selected_stone = "stone_basic"
		local view = match_view.for_bot(g)
		local mode = view:territory_mode()
		local owner_key = view:owner_key()
		local territory_before = territory_analysis.analyze(b, mode, owner_key)
		local base = features.build(b, view:ko_ban(), owner_key, mode, view:stone_color(), territory_before, nil)
		goals.refresh(view, base, territory_before)
		local found = false
		for i = 1, #g.ai_goals do
			if g.ai_goals[i].id == "cut_connectivity" then
				found = true
				break
			end
		end
		assert.is_true(found)
	end)

	it("cut_connectivity bonus applies when capture candidate and goal active", function()
		local g = match_state.new_match("pvc")
		g.ai_goals = { { id = "cut_connectivity", weight = 6 } }
		local view = match_view.for_bot(g)
		local bonus = goals.candidate_bonus(view, { delta_captures = 1 })
		assert.are.equal(6, bonus)
	end)
end)
