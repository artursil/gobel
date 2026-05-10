require("spec.test_helper")

local board = require("board")
local config = require("config")
local effect_registry = require("effect_registry")

local function find_effect_by_phase(resolved, phase)
	for i = 1, #resolved do
		if resolved[i].phase == phase then
			return resolved[i]
		end
	end
	return nil
end
local game = require("game")
local match_state = require("match_state")
local queries = require("single_game.resolver.state_queries")
local resolve_round = require("single_game.resolver.resolve_round")
local resolver = require("resolver")

describe("vertical slice features", function()
	it("blueprint copies immediate right stance effects", function()
		local state = {
			stances = {
				{ type = "stance_blueprint", owner = "B", index = 1 },
				{ type = "stance_point", owner = "B", index = 2 },
			},
			scores = {
				turn_bonus = { B = 1, W = 1 },
				territory = { B = 0, W = 0 },
				points = { B = 0, W = 0 },
				plus_mult = { B = 1, W = 1 },
				x_mult = { B = 1, W = 1 },
			},
		}
		local effects = effect_registry.stances.resolve(state.stances[1], state)
		assert.are.equal(4, #effects)
		local copy_points = find_effect_by_phase(effects, "points")
		assert.is_not_nil(copy_points)
		assert.are.equal("COPY_RIGHT_STANCE_EFFECTS", copy_points.type)
		local r = queries.ensure_resolution(state)
		r.phase = "points"
		r.source_stance_index = 1
		copy_points.apply(state, nil)
		assert.are.equal(1, state.scores.points.B)
	end)

	it("blueprint skips blueprint chains and no-ops without a target", function()
		local chain_state = {
			stances = {
				{ type = "stance_blueprint", owner = "B", index = 1 },
				{ type = "stance_blueprint", owner = "B", index = 2 },
				{ type = "stance_mult", owner = "B", index = 3 },
			},
			scores = {
				turn_bonus = { B = 1, W = 1 },
				territory = { B = 0, W = 0 },
				points = { B = 0, W = 0 },
				plus_mult = { B = 1, W = 1 },
				x_mult = { B = 1, W = 1 },
			},
		}
		local chain_effects = effect_registry.stances.resolve(chain_state.stances[1], chain_state)
		assert.are.equal(4, #chain_effects)
		local copy_mult = find_effect_by_phase(chain_effects, "mult")
		assert.is_not_nil(copy_mult)
		local r2 = queries.ensure_resolution(chain_state)
		r2.phase = "mult"
		r2.source_stance_index = 1
		copy_mult.apply(chain_state, nil)
		assert.are.equal(2, chain_state.scores.plus_mult.B)

		local empty_state = {
			stances = { { type = "stance_blueprint", owner = "B", index = 1 } },
			scores = {
				turn_bonus = { B = 1, W = 1 },
				territory = { B = 0, W = 0 },
				points = { B = 0, W = 0 },
				plus_mult = { B = 1, W = 1 },
				x_mult = { B = 1, W = 1 },
			},
		}
		local empty_effects = effect_registry.stances.resolve(empty_state.stances[1], empty_state)
		assert.are.equal(4, #empty_effects)
		local empty_pts = find_effect_by_phase(empty_effects, "points")
		local r3 = queries.ensure_resolution(empty_state)
		r3.phase = "points"
		r3.source_stance_index = 1
		empty_pts.apply(empty_state, nil)
		assert.are.equal(0, empty_state.scores.points.B)
	end)

	it("destroy card respects deterministic seeded pass/fail and invalid target safety", function()
		local state_fail = game.new("pvp", "vertical_slice_test")
		state_fail.rng.seed = 1
		state_fail.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic")
		state_fail.players.black.cards.hand.ids = { "card_destroy_enemy_stone" }
		state_fail.players.black.resources.energy_current = 10
		assert.is_true(game.select_board_target(state_fail, 4, 4))
		assert.is_true(game.play_card(state_fail, 1))
		assert.is_false(board.is_empty(state_fail.board[4][4]))

		local state_pass = game.new("pvp", "vertical_slice_test")
		state_pass.rng.seed = 4
		state_pass.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic")
		state_pass.players.black.cards.hand.ids = { "card_destroy_enemy_stone" }
		state_pass.players.black.resources.energy_current = 10
		assert.is_true(game.select_board_target(state_pass, 4, 4))
		assert.is_true(game.play_card(state_pass, 1))
		assert.is_true(board.is_empty(state_pass.board[4][4]))

		local state_invalid = game.new("pvp", "vertical_slice_test")
		state_invalid.board[4][4] = board.make_stone(config.STONE_WHITE, "stone_basic")
		state_invalid.players.black.cards.hand.ids = { "card_destroy_enemy_stone" }
		state_invalid.players.black.resources.energy_current = 10
		assert.is_true(game.select_board_target(state_invalid, 4, 4))
		state_invalid.board[4][4] = config.STONE_NONE
		assert.is_true(game.play_card(state_invalid, 1))
	end)

	it("persistent mult stance accumulates by tags and persists across new games in one run", function()
		local state = match_state.new_match("pvp", "regional", 1)
		state.run_state = { counters = {} }
		state.players.black.stances.fixed = { "stance_persistent_flux" }
		state.players.black.stances.swappable = {}
		state.players.white.stances.fixed = {}
		state.players.white.stances.swappable = {}
		state.to_play = "black"
		state.round_stone_effects = {
			{ owner = "B", stone_type = "stone_special", effects = {} },
		}
		resolve_round.resolve(state)
		assert.are.equal(3, state.run_state.counters.persistent_flux_mult.B)

		state.round_stone_effects = {
			{ owner = "B", stone_type = "stone_wall", effects = {} },
		}
		resolve_round.resolve(state)
		assert.are.equal(0, state.run_state.counters.persistent_flux_mult.B)

		local g1 = game.new("pvp", "vertical_slice_test")
		g1.run_state.counters.persistent_flux_mult = { B = 9, W = 0 }
		local g2 = game.new("pvp", "vertical_slice_test")
		assert.are.equal(9, g2.run_state.counters.persistent_flux_mult.B)
	end)

	it("permanent +10 card buffs selected stone across subsequent resolves", function()
		local state = game.new("pvp", "vertical_slice_test")
		state.board[4][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.players.black.cards.hand.ids = { "card_forge_mark" }
		state.players.black.resources.energy_current = 10
		assert.is_true(game.select_board_target(state, 4, 4))
		assert.is_true(game.play_card(state, 1))
		assert.are.equal(10, state.board_stone_modifiers["4:4"].points_bonus)
		local points_after_card = state.players.black.score.points
		resolve_round.resolve(state)
		assert.is_true(state.players.black.score.points >= points_after_card)
		assert.are.equal(10, state.board_stone_modifiers["4:4"].points_bonus)
	end)

	it("integration: target selection payload is required for targeted cards", function()
		local state = game.new("pvp", "vertical_slice_test")
		state.players.black.cards.hand.ids = { "card_destroy_enemy_stone" }
		state.players.black.resources.energy_current = 10
		local fail_result = resolver.submit_action(state, {
			actor = "black",
			type = "PLAY_CARD",
			payload = { hand_index = 1 },
		})
		assert.is_false(fail_result.ok)
		assert.are.equal("Card requires selected board target", fail_result.error)
	end)
end)
