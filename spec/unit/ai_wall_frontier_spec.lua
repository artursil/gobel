require("spec.test_helper")

local board = require("board")
local config = require("config")
local features = require("ai.board_analysis.features")
local match_state = require("match_state")
local match_view = require("ai.adapters.match_view")
local movegen = require("ai.movegen.placement_candidates")
local territory_analysis = require("ai.board_analysis.territory")

describe("ai wall frontier", function()
	it("detects empty cell orthogonally adjacent to own wall boundary", function()
		local b = board.new()
		b[5][4] = board.make_stone(config.STONE_WHITE, "stone_basic")
		local walls = {
			{ owner = config.OWNER_WHITE, boundary_fields = { { 5, 4 } } },
		}
		assert.is_true(features.is_on_my_wall_frontier(5, 5, walls, config.OWNER_WHITE))
		assert.is_true(features.is_placement_frontier(b, 5, 5, config.STONE_WHITE, walls, config.OWNER_WHITE))
	end)

	it("includes wall-frontier empty in candidate set with higher prescore than distant empty", function()
		local b = board.new()
		b[5][4] = board.make_stone(config.STONE_WHITE, "stone_basic")
		local walls = {
			{ owner = config.OWNER_WHITE, boundary_fields = { { 5, 4 } } },
		}
		local g = match_state.new_match("pvc")
		g.board = b
		g.phase = "PLACE_PHASE"
		g.to_play = "white"
		g.players.white.stones.playable_stones = { "stone_basic" }
		g.players.white.stones.selected_stone = "stone_basic"
		g.players.white.stones.selected_stone_index = 1
		local view = match_view.for_bot(g)
		local territory_before = territory_analysis.analyze(b, "regional", config.OWNER_WHITE)
		assert.is_true(features.is_placement_frontier(b, 5, 5, config.STONE_WHITE, walls, config.OWNER_WHITE))
		assert.is_false(features.is_placement_frontier(b, 1, 1, config.STONE_WHITE, walls, config.OWNER_WHITE))
		local candidates = movegen.top_candidates(view, "stone_basic", 30, territory_before, walls)
		local has_frontier = false
		for i = 1, #candidates do
			if candidates[i].row == 5 and candidates[i].col == 5 then
				has_frontier = true
			end
		end
		assert.is_true(has_frontier)
	end)
end)
