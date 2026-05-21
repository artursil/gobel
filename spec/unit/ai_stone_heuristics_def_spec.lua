require("spec.test_helper")

local ai_config = require("ai.config")
local board = require("board")
local config = require("config")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local placement_context = require("ai.heuristics.placement_context")
local spec_helper = require("spec.spec_helper")
local stone_heuristics_def = require("ai.heuristics.stone_heuristics_def")

local function capture_vs_interior_scores(g)
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
	g.players.white.stones.selected_stone = "stone_basic"
	local view = match_view.for_bot(g)
	local placement_cfg = ai_config.for_game(g).placement
	local capture_score, interior_score
	for r = 1, config.BOARD_SIZE do
		for c = 1, config.BOARD_SIZE do
			if board.is_empty(g.board[r][c]) then
				local ctx = placement_context.build(view, r, c, "stone_basic")
				if ctx then
					if ctx.captures > 0 then
						capture_score = stone_heuristics_def.sum_selection(ctx, placement_cfg)
					elseif r == 8 and c == 8 then
						interior_score = stone_heuristics_def.sum_selection(ctx, placement_cfg)
					end
				end
			end
		end
	end
	return capture_score, interior_score
end

describe("ai.heuristics.stone_heuristics_def", function()
	it("exports TERMS registry with expected ids", function()
		assert.is_table(stone_heuristics_def.TERMS)
		assert.is_function(stone_heuristics_def.TERMS.delta_captures.contribute)
		assert.is_function(stone_heuristics_def.TERMS.goals_bonus.contribute)
	end)

	it("disabling delta_captures in selection changes capture vs interior ranking", function()
		local g = match_state.new_match("pvc")
		ai_config.apply_profile(g, "normal")
		local capture_on, interior_on = capture_vs_interior_scores(g)
		assert.is_not_nil(capture_on)
		assert.is_not_nil(interior_on)
		assert.is_true(capture_on > interior_on)

		local g2 = match_state.new_match("pvc")
		ai_config.apply_profile(g2, "normal")
		g2.ai_placement.heuristics = { { id = "delta_captures", enabled = false } }
		local capture_off, interior_off = capture_vs_interior_scores(g2)
		assert.is_not_nil(capture_off)
		assert.is_not_nil(interior_off)
		assert.is_true(capture_off < capture_on)
	end)

	it("for_game exposes pre-selection and selection config keys", function()
		local g = {}
		ai_config.apply_profile(g, "normal")
		local s = ai_config.for_game(g)
		assert.is_true(#s.placement.heuristics_pre_selection >= 2)
		assert.is_true(#s.placement.heuristics_selection >= 8)
		assert.are.equal(12, s.placement.weights_pre_selection.delta_captures)
		assert.are.equal(4, s.placement.weights_selection.delta_territory_me)
	end)
end)
