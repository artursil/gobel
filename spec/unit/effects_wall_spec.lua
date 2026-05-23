require("spec.test_helper")

local config = require("config")
local effects = require("objects.effects")
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
	it("wall_stone_other adds +2 only on placed non-wall joining wall group", function()
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
			if resolved_list[i].type == "WALL_STONE_OTHER" then
				resolved_list[i].apply(st)
			end
		end
		assert.are.equal(2, st.board_stone_modifiers["3:5"].points_bonus)
		assert.is_nil(st.board_stone_modifiers["3:4"])
		assert.is_true(#st.ui_animation_events >= 1)
	end)

	it("wall_stone adds +2 to every stone in orthogonal group", function()
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
		assert.are.equal(2, st.board_stone_modifiers["4:4"].points_bonus)
		assert.are.equal(2, st.board_stone_modifiers["3:4"].points_bonus)
		assert.are.equal(2, st.board_stone_modifiers["3:5"].points_bonus)
		assert.are.equal(2, st.board_stone_modifiers["3:6"].points_bonus)
		assert.are.equal(2, st.board_stone_modifiers["4:5"].points_bonus)
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
end)

describe("pattern mult effects", function()
	it("pattern_x_mult multiplies x_mult when X includes x_stone", function()
		local st = state_with_board({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . X . X . . .",
			". . . . X . . . .",
			". . . X . X . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			X = { color = config.STONE_BLACK, kind = "x_stone" },
		})
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
			". . . . P . . . .",
			". . . P P P . . .",
			". . . . P . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			P = { color = config.STONE_WHITE, kind = "plus_stone" },
		})
		st._pattern_apply_keys = {}
		local resolved = effects.resolve({ effect_name = "pattern_plus_mult", phase = "mult" })
		resolved.apply(st, config.OWNER_WHITE)
		assert.are.equal(6, st.scores.plus_mult.W)
	end)
end)
