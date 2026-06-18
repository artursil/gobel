require("spec.test_helper")

local board = require("board")
local config = require("config")
local effect_manager = require("single_game.resolver.effect_manager")
local ObjectInstance = require("single_game.resolver.ObjectInstance")
local queries = require("single_game.resolver.helpers.state_queries")
local stance_order = require("single_game.resolver.stance_order")

local function minimal_scores()
	return {
		turn_bonus = { B = 1, W = 1 },
		territory = { B = 0, W = 0 },
		points = { B = 0, W = 0 },
		plus_mult = { B = 1, W = 1 },
		x_mult = { B = 1, W = 1 },
	}
end

describe("state.resolution metadata wiring", function()
	it("stance effects carry meta.source_instance_id from ObjectInstance.instance_id", function()
		local inst = ObjectInstance.new("run_inst_test", "stance_point", "temporary_stance", config.OWNER_BLACK, "starter", {})
		local state = {
			board = board.new(),
			players = {
				black = { stances = { fixed = {}, swappable = {} } },
				white = { stances = { fixed = {}, swappable = {} } },
			},
			temporary_stances = { inst },
			just_played = {},
			played_cards = {},
			round_stone_effects = {},
			active_effects = {},
			scores = minimal_scores(),
		}
		stance_order.flatten_stances_for_resolve(state)
		local effects = effect_manager.collect_effects(state, "before_turn", "points", nil)
		assert.are.equal(1, #effects)
		assert.are.equal("run_inst_test", effects[1].meta.source_instance_id)
	end)

	it("during apply_phase_pass, stance effects see resolution.source_instance_id from the stance row", function()
		local em = effect_manager
		local orig_collect = em.collect_effects
		local seen_id

		em.collect_effects = function(match_state, action, phase, territory_step)
			local list = orig_collect(match_state, action, phase, territory_step)
			for _, e in ipairs(list) do
				if e.meta and e.meta.source_object_type == "stance" then
					local inner = e.apply
					e.apply = function(inner_state, a, b)
						seen_id = queries.ensure_resolution(inner_state).source_instance_id
						return inner(inner_state, a, b)
					end
					break
				end
			end
			return list
		end

		local inst = ObjectInstance.new("phase_inst_stance", "stance_point", "temporary_stance", config.OWNER_BLACK, "starter", {})
		local state = {
			board = board.new(),
			players = {
				black = { stances = { fixed = {}, swappable = {} } },
				white = { stances = { fixed = {}, swappable = {} } },
			},
			temporary_stances = { inst },
			just_played = {},
			played_cards = {},
			round_stone_effects = {},
			active_effects = {},
			scores = minimal_scores(),
		}
		stance_order.flatten_stances_for_resolve(state)

		em.apply_phase_pass(state, "before_turn", "points", nil)
		em.collect_effects = orig_collect

		assert.are.equal("phase_inst_stance", seen_id)
	end)

	it("during apply_phase_pass, stone round effects see resolution.effect_owner as stone_event.owner", function()
		local em = effect_manager
		local orig_collect = em.collect_effects
		local seen_owner

		em.collect_effects = function(match_state, action, phase, territory_step)
			local list = orig_collect(match_state, action, phase, territory_step)
			for _, e in ipairs(list) do
				if e.meta and e.meta.source_object_type == "stone" then
					local inner = e.apply
					e.apply = function(inner_state, a, b)
						seen_owner = queries.ensure_resolution(inner_state).effect_owner
						return inner(inner_state, a, b)
					end
				end
			end
			return list
		end

		local state = {
			board = board.new(),
			players = {
				black = { stances = { fixed = {}, swappable = {} } },
				white = { stances = { fixed = {}, swappable = {} } },
			},
			temporary_stances = {},
			just_played = {},
			played_cards = {},
			round_stone_effects = {
				{
					owner = "W",
					stone_type = "stone_basic",
					effects = {
						{
							effect_name = "add_points",
							action = "on_play",
							phase = "points",
							value = 2,
							priority = 10,
						},
					},
				},
			},
			active_effects = {},
			scores = minimal_scores(),
		}

		em.apply_phase_pass(state, "on_play", "points", nil)
		em.collect_effects = orig_collect

		assert.are.equal("W", seen_owner)
		assert.are.equal(2, state.scores.points.W)
	end)
end)
