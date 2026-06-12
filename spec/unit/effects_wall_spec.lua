require("spec.test_helper")

local board = require("board")
local config = require("config")
local content = require("content")
local effects = require("objects.effects")
local shape_patterns = require("game.patterns.shape_patterns")
local effect_manager = require("single_game.resolver.effect_manager")
local placement_effects = require("single_game.resolver.placement_effects")
local spec_helper = require("spec.spec_helper")
local P = require("spec.parameters_helper")

local function state_with_board(rows, letter_map)
	local b = spec_helper.parse_board_ascii_kinds(rows, letter_map)
	return {
		board = b,
		scores = {
			turn_bonus = { B = 1, W = 1 },
			territory = { B = 0, W = 0 },
			points = { B = P.starting_points(), W = P.starting_points() },
			plus_mult = { B = 1, W = 1 },
			x_mult = { B = 1, W = 1 },
		},
		board_stone_modifiers = {},
		run_state = { pattern_apply_keys = {} },
		last_opponent_move = nil,
		round_stone_effects = {},
		ui_animation_events = {},
	}
end

--- Issue #31 / mds/STONES_IMPLEMENTATION_ENTRY.md §26: wall bonus runs only on placement via round_stone_effects, never board scan.
--- @param st table
local function apply_wall_placement_effects(st)
	local wall_def = content.resolve_stone("wall")
	st.round_stone_effects = {
		{
			owner = "B",
			stone_type = "wall",
			effects = placement_effects.collect_defs(wall_def),
		},
	}
	effect_manager.apply_sub_phase(st, "playing_stones", "points", nil)
end

describe("wall stone effects", function()
	it("basic stone beside walls does not trigger wall_stone", function()
		local st = state_with_board({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			W = { color = config.STONE_BLACK, kind = "wall" },
			B = { color = config.STONE_BLACK, kind = "stone_basic" },
		})
		st.last_opponent_move = { row = 3, col = 5, stone_id = "stone_basic", actor = "black" }
		local cell = st.board[3][5]
		local resolved_list = effects.resolve_board_stone(cell, 3, 5, st, "playing_stones", "points", nil)
		for i = 1, #resolved_list do
			assert.are_not.equal("WALL_STONE", resolved_list[i].type)
		end
		assert.is_nil(st.board_stone_modifiers["3:5"])
	end)

	it("wall_stone adds +5 when placed into a group of 5 connected stones", function()
		local st = state_with_board({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B . . .",
			". . . W B . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			W = { color = config.STONE_BLACK, kind = "wall" },
			B = { color = config.STONE_BLACK, kind = "stone_basic" },
		})
		st.last_opponent_move = { row = 4, col = 4, stone_id = "wall", actor = "black" }
		apply_wall_placement_effects(st)
		assert.are.equal(P.points_after_wall_bonus(P.starting_points(), 5), st.scores.points.B)
		assert.is_true(#st.ui_animation_events >= 1)
	end)

	it("wall_stone adds +10 when placed into a group of 10 connected stones", function()
		local st = state_with_board({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B B B B B . .",
			". . . B B W B B . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			W = { color = config.STONE_BLACK, kind = "wall" },
			B = { color = config.STONE_BLACK, kind = "stone_basic" },
		})
		local wall_r, wall_c = 5, 6
		local group = shape_patterns.group_connected(st.board, wall_r, wall_c)
		assert.are.equal(10, #group)
		st.last_opponent_move = { row = wall_r, col = wall_c, stone_id = "wall", actor = "black" }
		apply_wall_placement_effects(st)
		assert.are.equal(P.points_after_wall_bonus(P.starting_points(), 10), st.scores.points.B)
	end)

	it("wall_stone adds nothing when group has fewer than 5 stones", function()
		local st = state_with_board({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			W = { color = config.STONE_BLACK, kind = "wall" },
		})
		st.last_opponent_move = { row = 3, col = 4, stone_id = "wall", actor = "black" }
		apply_wall_placement_effects(st)
		assert.are.equal(P.starting_points(), st.scores.points.B)
	end)

	it("resolve_board_stone on wall cell does not emit wall_stone effect", function()
		local st = state_with_board({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . W . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			W = { color = config.STONE_BLACK, kind = "wall" },
		})
		st.last_opponent_move = { row = 3, col = 4, stone_id = "wall", actor = "black" }
		local cell = st.board[3][4]
		local generated = effects.resolve_board_stone(cell, 3, 4, st, "playing_stones", "points", nil)
		for i = 1, #generated do
			assert.are_not.equal("WALL_STONE", generated[i].type)
		end
	end)

	it("wall_points_for_connected_group_size", function()
		local block = P.stone.wall_stones_per_block
		local per_block = P.stone.wall_points_per_block
		assert.are.equal(0, shape_patterns.wall_points_for_connected_group_size(block - 1))
		assert.are.equal(per_block, shape_patterns.wall_points_for_connected_group_size(block))
		assert.are.equal(per_block, shape_patterns.wall_points_for_connected_group_size(block + block - 1))
		assert.are.equal(per_block * 2, shape_patterns.wall_points_for_connected_group_size(block * 2))
	end)
end)

describe("pattern mult effects", function()
	it("pattern_x_mult multiplies x_mult when placement completes an X with x_stone", function()
		local st = state_with_board({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B . B . . .",
			". . . . . . . . .",
			". . . B . B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			B = { color = config.STONE_BLACK, kind = "stone_basic" },
		})
		st.board[4][5] = board.make_stone(config.STONE_BLACK, "x_stone")
		st.last_opponent_move = { row = 4, col = 5, stone_id = "x_stone", actor = "black" }
		st.run_state = { pattern_apply_keys = {} }
		local resolved = effects.resolve({ effect_name = "pattern_x_mult", phase = "mult" })
		resolved.apply(st, config.OWNER_BLACK)
		assert.are.equal(P.x_mult_after(P.base_x_mult(), 1), st.scores.x_mult.B)
		assert.is_true(#st.ui_animation_events > 0)
	end)

	it("pattern_plus_mult adds plus_mult when + includes plus_stone", function()
		local st = state_with_board({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . B . . .",
			". . . . B . B . .",
			". . . . . B . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			B = { color = config.STONE_WHITE, kind = "stone_basic" },
		})
		st.board[5][6] = board.make_stone(config.STONE_WHITE, "plus_stone")
		st.last_opponent_move = { row = 5, col = 6, stone_id = "plus_stone", actor = "white" }
		st.run_state = { pattern_apply_keys = {} }
		local resolved = effects.resolve({ effect_name = "pattern_plus_mult", phase = "mult" })
		resolved.apply(st, config.OWNER_WHITE)
		assert.are.equal(P.plus_mult_after(P.base_plus_mult(), 1), st.scores.plus_mult.W)
	end)
end)
