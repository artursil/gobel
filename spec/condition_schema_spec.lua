require("spec.test_helper")

local run_state = require("single_run.run_state")
local game_state = require("single_game.game_state")
local Condition = require("single_game.resolver.Condition")

describe("T-203 Condition schema runtime", function()
	it("creates condition context with all schema fields", function()
		local rs = run_state.new("run1", 42)
		local gs = game_state.new("game1", 1)

		local context = Condition.new_context(rs, gs, "A", "inst_1", "stone_basic", "stone")

		assert.are.equal(rs, context.run_state)
		assert.are.equal(gs, context.game_state)
		assert.are.equal("A", context.actor)
		assert.are.equal("B", context.opponent)
		assert.are.equal("inst_1", context.source_instance_id)
		assert.are.equal("stone_basic", context.source_def_id)
		assert.are.equal("stone", context.source_object_type)
		assert.is_not_nil(context.rng)
		assert.is_not_nil(context.rng.next_float)
		assert.is_not_nil(context.rng.next_int)
	end)

	it("evaluates always condition", function()
		local context = Condition.new_context(nil, nil, "A")
		assert.is_true(Condition.eval_single({ condition_name = "always" }, context))
	end)

	it("evaluates never condition", function()
		local context = Condition.new_context(nil, nil, "A")
		assert.is_false(Condition.eval_single({ condition_name = "never" }, context))
	end)

	it("evaluates random condition", function()
		local rs = run_state.new("run1", 42)
		local context = Condition.new_context(rs, nil, "A")

		local result = Condition.eval_single({ condition_name = "random", value = 1.0 }, context)
		assert.is_true(result)

		result = Condition.eval_single({ condition_name = "random", value = 0.0 }, context)
		assert.is_false(result)
	end)

	it("evaluates prisoners_captured_at_least condition", function()
		local gs = game_state.new("game1", 1)
		gs.players.A.counters.prisoners_captured = 3

		local context = Condition.new_context(nil, gs, "A")

		assert.is_true(Condition.eval_single({ condition_name = "prisoners_captured_at_least", value = 3 }, context))
		assert.is_true(Condition.eval_single({ condition_name = "prisoners_captured_at_least", value = 2 }, context))
		assert.is_false(Condition.eval_single({ condition_name = "prisoners_captured_at_least", value = 4 }, context))
	end)

	it("evaluates turn_number_at_least condition", function()
		local gs = game_state.new("game1", 1)
		gs.meta.turn_number = 5

		local context = Condition.new_context(nil, gs, "A")

		assert.is_true(Condition.eval_single({ condition_name = "turn_number_at_least", value = 5 }, context))
		assert.is_true(Condition.eval_single({ condition_name = "turn_number_at_least", value = 3 }, context))
		assert.is_false(Condition.eval_single({ condition_name = "turn_number_at_least", value = 6 }, context))
	end)

	it("evaluates all conditions (all must pass)", function()
		local gs = game_state.new("game1", 1)
		local context = Condition.new_context(nil, gs, "A")

		local conditions = {
			{ condition_name = "always" },
			{ condition_name = "always" },
		}
		assert.is_true(Condition.eval_all(conditions, context))

		conditions = {
			{ condition_name = "always" },
			{ condition_name = "never" },
		}
		assert.is_false(Condition.eval_all(conditions, context))
	end)

	it("eval_all returns true for nil or empty conditions", function()
		assert.is_true(Condition.eval_all(nil, {}))
		assert.is_true(Condition.eval_all({}, {}))
	end)

	it("RNG context produces different values per key", function()
		local rs = run_state.new("run1", 42)
		local context = Condition.new_context(rs, nil, "A")

		local f1 = context.rng.next_float("key1")
		local f2 = context.rng.next_float("key2")

		assert.are_not_equal(f1, f2)
	end)
end)
