require("spec.test_helper")

local ai_config = require("ai.config")
local board = require("board")
local config = require("config")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local placement = require("ai.heuristics.placement")
local spec_helper = require("spec.spec_helper")

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
	local capture_score, interior_score
	for r = 1, config.BOARD_SIZE do
		for c = 1, config.BOARD_SIZE do
			if board.is_empty(g.board[r][c]) then
				local scored = placement.evaluate_move(view, r, c, "stone_basic")
				if scored and scored.delta_captures > 0 then
					capture_score = scored.score
				elseif r == 8 and c == 8 and scored then
					interior_score = scored.score
				end
			end
		end
	end
	return capture_score, interior_score
end

describe("ai.heuristics.placement registry", function()
	it("disabling delta_captures changes capture vs interior ranking", function()
		local g = match_state.new_match("pvc")
		ai_config.apply_profile(g, "normal")
		local capture_on, interior_on = capture_vs_interior_scores(g)
		assert.is_not_nil(capture_on)
		assert.is_not_nil(interior_on)
		assert.is_true(capture_on > interior_on)

		local g2 = match_state.new_match("pvc")
		ai_config.apply_profile(g2, "normal")
		local heuristics = {}
		for i = 1, #g2.ai_placement.heuristics do
			local entry = g2.ai_placement.heuristics[i]
			heuristics[i] = {
				id = entry.id,
				enabled = entry.id ~= "delta_captures" and entry.enabled or false,
			}
		end
		g2.ai_placement.heuristics = heuristics
		local capture_off, interior_off = capture_vs_interior_scores(g2)
		assert.is_not_nil(capture_off)
		assert.is_not_nil(interior_off)
		assert.is_true(capture_off < capture_on)
	end)

	it("for_game exposes placement heuristics list", function()
		local g = {}
		ai_config.apply_profile(g, "normal")
		local s = ai_config.for_game(g)
		assert.is_true(#s.placement.heuristics >= 9)
		local found = false
		for i = 1, #s.placement.heuristics do
			if s.placement.heuristics[i].id == "delta_captures" then
				found = true
				assert.is_true(s.placement.heuristics[i].enabled)
			end
		end
		assert.is_true(found)
	end)
end)
