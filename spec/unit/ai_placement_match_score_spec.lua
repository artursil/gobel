require("spec.test_helper")

local board = require("board")
local config = require("config")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local placement_match_score = require("ai.scoring.placement_match_score")
local rules = require("rules")
local spec_helper = require("spec.spec_helper")

describe("ai.scoring.placement_match_score", function()
	it("ADD_POINTS stone ranks capture above empty dame on toy board", function()
		local g = match_state.new_match("pvc")
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
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.players.white.score.territory = 10
		g.players.white.score.points = 2
		g.players.white.score.turn_bonus = 1
		g.players.white.score.plus_mult = 1
		g.players.white.score.x_mult = 1
		g.players.white.stones.selected_stone = "stone_basic"
		local view = match_view.for_bot(g)
		local stone_id = "stone_basic"
		local player = config.STONE_WHITE
		local capture_row, capture_col
		local dame_row, dame_col
		for r = 1, config.BOARD_SIZE do
			for c = 1, config.BOARD_SIZE do
				if board.is_empty(g.board[r][c]) then
					local ok, _trial, _ko, captures = rules.try_play(g.board, r, c, player, g.ko_ban, stone_id)
					if ok and captures > 0 and not capture_row then
						capture_row, capture_col = r, c
					elseif ok and captures == 0 and r == 1 and c == 1 and not dame_row then
						dame_row, dame_col = r, c
					end
				end
			end
		end
		assert.is_not_nil(capture_row)
		assert.is_not_nil(dame_row)
		local capture_delta = placement_match_score.score_delta(view, stone_id, capture_row, capture_col)
		local dame_delta = placement_match_score.score_delta(view, stone_id, dame_row, dame_col)
		assert.is_not_nil(capture_delta)
		assert.is_not_nil(dame_delta)
		assert.is_true(capture_delta > dame_delta)
	end)

	it("returns nil for illegal moves", function()
		local g = match_state.new_match("pvc")
		g.board = board.new()
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.board[5][5] = board.make_stone(config.STONE_WHITE, "stone_basic")
		local view = match_view.for_bot(g)
		assert.is_nil(placement_match_score.score_delta(view, "stone_basic", 5, 5))
	end)
end)
