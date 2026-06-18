require("spec.test_helper")

local board = require("board")
local config = require("config")
local run = require("objects.effects_conditions.run")
local effects = require("objects.effects_conditions.effects")
local P = require("spec.parameters_helper")

local function base_state()
	return {
		board = board.new(),
		scores = {
			points = { B = P.starting_points(), W = P.starting_points() },
			plus_mult = { B = 1, W = 1 },
			x_mult = { B = 1, W = 1 },
			turn_bonus = { B = 1, W = 1 },
			territory = { B = 0, W = 0 },
		},
		ui_animation_events = {},
		last_opponent_move = nil,
	}
end

describe("effects_conditions run.apply_effect", function()
	it("skips apply when a condition fails", function()
		local state = base_state()
		local applied = false
		local effect = {
			conditions = { { condition_name = "never" } },
			apply = function()
				applied = true
			end,
		}
		assert.is_false(run.apply_effect(effect, state, config.OWNER_BLACK))
		assert.is_false(applied)
		assert.are.equal(P.starting_points(), state.scores.points.B)
	end)

	it("calls apply with kwargs table when conditions pass without fragments", function()
		local seen_kwargs = nil
		local effect = {
			conditions = { { condition_name = "always" } },
			apply = function(_state, _owner, kwargs)
				seen_kwargs = kwargs
			end,
		}
		assert.is_true(run.apply_effect(effect, base_state(), config.OWNER_BLACK))
		assert.is_table(seen_kwargs)
		assert.is_nil(seen_kwargs.blocks)
	end)

	it("skips apply when wall_part_of_wall fails for undersized group", function()
		local state = base_state()
		state.board[3][4] = board.make_stone(config.STONE_BLACK, "wall")
		state.last_opponent_move = { row = 3, col = 4, stone_id = "wall", actor = "black" }
		local resolved = effects.resolve({
			action = "on_play",
			phase = "points",
			effect_name = "wall_stone",
			conditions = {
				{ condition_name = "wall_part_of_wall" },
			},
		})
		assert.is_false(run.apply_effect(resolved, state, config.OWNER_BLACK))
		assert.are.equal(P.starting_points(), state.scores.points.B)
	end)

	it("applies wall points when wall_part_of_wall passes with merged blocks kwargs", function()
		local state = base_state()
		state.board[3][3] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[3][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[3][5] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[4][5] = board.make_stone(config.STONE_BLACK, "wall")
		state.last_opponent_move = { row = 4, col = 5, stone_id = "wall", actor = "black" }
		local resolved = effects.resolve({
			action = "on_play",
			phase = "points",
			effect_name = "wall_stone",
			conditions = {
				{ condition_name = "wall_part_of_wall" },
			},
		})
		assert.is_true(run.apply_effect(resolved, state, config.OWNER_BLACK))
		assert.are.equal(P.points_after_wall_bonus(P.starting_points(), 5), state.scores.points.B)
	end)

	it("errors when required kwargs keys are missing", function()
		local state = base_state()
		local resolved = effects.resolve({
			action = "on_play",
			phase = "points",
			effect_name = "wall_stone",
		})
		assert.has_error(function()
			resolved.apply(state, config.OWNER_BLACK, {})
		end, "missing required kwargs key: blocks")
	end)
end)
