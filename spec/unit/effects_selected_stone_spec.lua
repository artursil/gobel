require("spec.test_helper")

local board = require("board")
local config = require("config")
local effects = require("objects.effects_conditions.effects")
local run = require("objects.effects_conditions.run")
local conditions = require("objects.effects_conditions.conditions")
local pending_removals = require("objects.effects_conditions.helpers.shared.pending_removals")
local remove_stones = require("single_game.resolver.stages.remove_stones")
local queries = require("single_game.resolver.helpers.state_queries")

local function state_with_target(row, col, stone_color, solidity)
	local test_helper = require("spec.test_helper")
	local st = test_helper.new_isolated_game("basic_stones")
	st.board[row][col] = board.make_stone(stone_color, "stone_basic", solidity)
	local resolution = queries.ensure_resolution(st)
	resolution.effect_owner = config.OWNER_WHITE
	resolution.selected_targets = {
		{ object_type = "stone", row = row, col = col },
	}
	return st
end

describe("selected-stone card effects", function()
	it("damage_selected_stone build returns inline apply only", function()
		local resolved = effects.resolve({
			effect_name = "damage_selected_stone",
			action = "on_card",
			phase = "points",
			value = { amount = 1 },
		})
		assert.is_not_nil(resolved.apply)
		assert.is_nil(resolved.on_tick)
		assert.is_nil(resolved.kwargs_from_def)
	end)

	it("lethal damage enqueues removal without clearing board in apply", function()
		local st = state_with_target(4, 4, config.STONE_BLACK, 1)
		local resolved = effects.resolve({
			effect_name = "damage_selected_stone",
			action = "on_card",
			phase = "points",
			value = { amount = 1 },
		})
		assert.is_true(run.apply_effect(resolved, st, config.OWNER_WHITE))
		assert.is_false(board.is_empty(st.board[4][4]))
		assert.are.equal(0, st.board[4][4].solidity)
		assert.are.equal(1, pending_removals.pending_count(st))
		remove_stones.run({ state = st, actor = "white", player_chain_color = config.STONE_WHITE })
		assert.is_true(board.is_empty(st.board[4][4]))
	end)

	it("non-lethal damage reduces solidity without enqueue", function()
		local st = state_with_target(4, 4, config.STONE_BLACK, 4)
		local resolved = effects.resolve({
			effect_name = "damage_selected_stone",
			action = "on_card",
			phase = "points",
			value = { amount = 1 },
		})
		assert.is_true(run.apply_effect(resolved, st, config.OWNER_WHITE))
		assert.are.equal(3, st.board[4][4].solidity)
		assert.are.equal(0, pending_removals.pending_count(st))
	end)

	it("heal_selected_stone restores solidity up to max", function()
		local st = state_with_target(4, 4, config.STONE_BLACK, 2)
		local resolved = effects.resolve({
			effect_name = "heal_selected_stone",
			action = "on_card",
			phase = "points",
			value = { amount = 1 },
		})
		assert.is_true(run.apply_effect(resolved, st, config.OWNER_BLACK))
		assert.are.equal(3, st.board[4][4].solidity)
	end)

	it("destroy enqueues on successful roll and conditions gate enemy", function()
		local st = state_with_target(4, 4, config.STONE_WHITE, 4)
		st.rng = { seed = 4 }
		local resolution = queries.ensure_resolution(st)
		resolution.effect_owner = config.OWNER_BLACK
		local resolved = effects.resolve({
			effect_name = "destroy_selected_enemy_stone",
			action = "on_card",
			phase = "points",
			value = { chance_numerator = 1, chance_denominator = 4 },
			conditions = {
				{ condition_name = "selected_target_exists" },
				{ condition_name = "selected_target_is_enemy_stone" },
			},
		})
		assert.is_true(run.apply_effect(resolved, st, config.OWNER_BLACK))
		assert.is_false(board.is_empty(st.board[4][4]))
		assert.are.equal(1, pending_removals.pending_count(st))
	end)

	it("forge adds permanent points when friendly gate passes", function()
		local st = state_with_target(4, 4, config.STONE_BLACK, 4)
		local resolution = queries.ensure_resolution(st)
		resolution.effect_owner = config.OWNER_BLACK
		local resolved = effects.resolve({
			effect_name = "add_permanent_points_to_selected_stone",
			action = "on_card",
			phase = "points",
			value = { points = 10 },
			conditions = {
				{ condition_name = "selected_target_exists" },
				{ condition_name = "selected_target_is_friendly_stone" },
			},
		})
		assert.is_true(run.apply_effect(resolved, st, config.OWNER_BLACK))
		assert.are.equal(10, st.board_stone_modifiers["4:4"].points_bonus)
	end)

	it("selected_target_is_enemy_stone fails on friendly cell", function()
		local st = state_with_target(4, 4, config.STONE_BLACK, 4)
		local resolution = queries.ensure_resolution(st)
		resolution.effect_owner = config.OWNER_BLACK
		local pass = conditions.eval({ condition_name = "selected_target_is_enemy_stone" }, st, config.OWNER_BLACK)
		assert.is_false(pass)
	end)
end)
