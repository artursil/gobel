require("spec.test_helper")

local board = require("board")
local config = require("config")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local placement = require("ai.heuristics.placement")
local spec_helper = require("spec.spec_helper")

describe("ai.heuristics.placement", function()
	it("prefers capture over interior fill on crafted board", function()
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
		g.players.white.stones.selected_stone = "stone_basic"
		local view = match_view.for_bot(g)
		local capture_candidate = nil
		local interior_candidate = nil
		for r = 1, config.BOARD_SIZE do
			for c = 1, config.BOARD_SIZE do
				if board.is_empty(b[r][c]) then
					local scored = placement.evaluate_move(view, r, c, "stone_basic")
					if scored and scored.delta_captures > 0 then
						capture_candidate = scored
					elseif r == 8 and c == 8 and scored and scored.delta_captures == 0 then
						interior_candidate = scored
					end
				end
			end
		end
		assert.is_not_nil(capture_candidate)
		assert.is_not_nil(interior_candidate)
		assert.is_true(capture_candidate.score > interior_candidate.score)
	end)
end)
