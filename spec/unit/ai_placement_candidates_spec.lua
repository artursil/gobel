require("spec.test_helper")

local board = require("board")
local config = require("config")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local placement_candidates = require("ai.movegen.placement_candidates")
local rules = require("rules")
local spec_helper = require("spec.spec_helper")

local function view_for_board(b, stone_id)
	local g = match_state.new_match("pvc")
	g.board = b
	g.phase = "PLACE_PHASE"
	g.to_play = "white"
	g.players.white.stones.playable_stones = { stone_id }
	g.players.white.stones.selected_stone = stone_id
	g.players.white.stones.selected_stone_index = 1
	return match_view.for_bot(g)
end

describe("ai.movegen.placement_candidates", function()
	it("returns a subset of legal moves", function()
		local b = board.new()
		local view = view_for_board(b, "stone_basic")
		local legal = rules.all_legal_moves(b, config.STONE_WHITE, nil, "stone_basic")
		local candidates = placement_candidates.top_candidates(view, "stone_basic", 10)
		assert.is_true(#candidates <= 10)
		assert.is_true(#candidates <= #legal)
		for i = 1, #candidates do
			local ok = select(1, rules.try_play(b, candidates[i].row, candidates[i].col, config.STONE_WHITE, nil, "stone_basic"))
			assert.is_true(ok)
		end
	end)

	it("includes capture moves when present", function()
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
		local view = view_for_board(b, "stone_basic")
		local legal = rules.all_legal_moves(b, config.STONE_WHITE, nil, "stone_basic")
		local capture_moves = {}
		for i = 1, #legal do
			local r, c = legal[i][1], legal[i][2]
			local ok, _t, _k, caps = rules.try_play(b, r, c, config.STONE_WHITE, nil, "stone_basic")
			if ok and caps > 0 then
				capture_moves[#capture_moves + 1] = { row = r, col = c }
			end
		end
		assert.is_true(#capture_moves >= 1)
		local candidates = placement_candidates.top_candidates(view, "stone_basic", 30)
		local found = false
		for i = 1, #candidates do
			for j = 1, #capture_moves do
				if candidates[i].row == capture_moves[j].row and candidates[i].col == capture_moves[j].col then
					found = true
				end
			end
		end
		assert.is_true(found)
	end)
end)
