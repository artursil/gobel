require("spec.test_helper")

local board = require("board")
local config = require("config")
local effects = require("objects.effects")
local shape_patterns = require("game.patterns.shape_patterns")
local spec_helper = require("spec.spec_helper")

local function state_with_board(rows, letter_map)
	local b = spec_helper.parse_board_ascii_kinds(rows, letter_map)
	return {
		board = b,
		scores = {
			turn_bonus = { B = 1, W = 1 },
			territory = { B = 0, W = 0 },
			points = { B = 1, W = 1 },
			plus_mult = { B = 1, W = 1 },
			x_mult = { B = 1, W = 1 },
		},
		board_stone_modifiers = {},
		_pattern_apply_keys = {},
		last_opponent_move = nil,
		ui_animation_events = {},
	}
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
		local cell = st.board[4][4]
		local resolved_list = effects.resolve_board_stone(cell, 4, 4, st, "playing_stones", "points", nil)
		for i = 1, #resolved_list do
			if resolved_list[i].type == "WALL_STONE" then
				resolved_list[i].apply(st)
			end
		end
		assert.are.equal(6, st.scores.points.B)
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
		local cell = st.board[wall_r][wall_c]
		local resolved_list = effects.resolve_board_stone(cell, wall_r, wall_c, st, "playing_stones", "points", nil)
		for i = 1, #resolved_list do
			if resolved_list[i].type == "WALL_STONE" then
				resolved_list[i].apply(st)
			end
		end
		assert.are.equal(11, st.scores.points.B)
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
		local cell = st.board[3][4]
		local resolved_list = effects.resolve_board_stone(cell, 3, 4, st, "playing_stones", "points", nil)
		for i = 1, #resolved_list do
			if resolved_list[i].type == "WALL_STONE" then
				resolved_list[i].apply(st)
			end
		end
		assert.are.equal(1, st.scores.points.B)
	end)

	it("resolve_board_stone on wall cell includes wall_stone effect", function()
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
		local has_wall = false
		for i = 1, #generated do
			if generated[i].type == "WALL_STONE" then
				has_wall = true
			end
		end
		assert.is_true(has_wall)
	end)

	it("wall_points_for_connected_group_size", function()
		assert.are.equal(0, shape_patterns.wall_points_for_connected_group_size(4))
		assert.are.equal(5, shape_patterns.wall_points_for_connected_group_size(5))
		assert.are.equal(5, shape_patterns.wall_points_for_connected_group_size(9))
		assert.are.equal(10, shape_patterns.wall_points_for_connected_group_size(10))
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
		st._pattern_apply_keys = {}
		local resolved = effects.resolve({ effect_name = "pattern_x_mult", phase = "mult" })
		resolved.apply(st, config.OWNER_BLACK)
		assert.are.equal(2, st.scores.x_mult.B)
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
		st._pattern_apply_keys = {}
		local resolved = effects.resolve({ effect_name = "pattern_plus_mult", phase = "mult" })
		resolved.apply(st, config.OWNER_WHITE)
		assert.are.equal(6, st.scores.plus_mult.W)
	end)
end)
