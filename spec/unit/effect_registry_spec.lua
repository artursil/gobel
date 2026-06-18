require("spec.test_helper")

local board = require("board")
local config = require("config")
local effect_registry = require("effect_registry")
local objects_effects = require("objects.effects_conditions.effects")
local run = require("objects.effects_conditions.run")
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

describe("effect_registry", function()
	local original_resolve_stance_effects

	before_each(function()
		original_resolve_stance_effects = objects_effects.resolve_stance_definition_effects
	end)

	after_each(function()
		objects_effects.resolve_stance_definition_effects = original_resolve_stance_effects
	end)

	it("stance resolved effects expose apply", function()
		local effects = effect_registry.stances.resolve(
			{ type = "stance_point", owner = config.OWNER_BLACK },
			{}
		)
		assert.is_true(#effects > 0)
		for i = 1, #effects do
			assert.is_function(effects[i].apply)
		end
	end)

	it("card resolved effects expose apply", function()
		local effects = effect_registry.cards.resolve({
			type = "card_forge_mark",
			owner = config.OWNER_BLACK,
			selected_target = { row = 4, col = 4 },
		})
		assert.is_true(#effects > 0)
		for i = 1, #effects do
			assert.is_function(effects[i].apply)
		end
	end)

	it("stance wrapper forwards kwargs from run.apply_effect", function()
		objects_effects.resolve_stance_definition_effects = function(_stance_type)
			return {
				objects_effects.resolve({
					effect_name = "wall_stone",
					action = "on_play",
					phase = "points",
					conditions = {
						{ condition_name = "wall_part_of_wall" },
					},
				}),
			}
		end

		local state = base_state()
		state.board[3][3] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[3][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[3][5] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[4][5] = board.make_stone(config.STONE_BLACK, "wall")
		state.last_opponent_move = { row = 4, col = 5, stone_id = "wall", actor = "black" }

		local effects = effect_registry.stances.resolve(
			{ type = "stance_point", owner = config.OWNER_BLACK },
			state
		)
		assert.is_function(effects[1].apply)
		assert.is_true(run.apply_effect(effects[1], state, config.OWNER_BLACK))
		assert.are.equal(P.points_after_wall_bonus(P.starting_points(), 5), state.scores.points.B)
	end)
end)
