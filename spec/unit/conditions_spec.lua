require("spec.test_helper")

local conditions = require("objects.conditions")

describe("T-101 conditions system", function()
	it("evaluates always condition as true", function()
		assert.is_true(conditions.always({}))
	end)

	it("evaluates never condition as false", function()
		assert.is_false(conditions.never({}))
	end)

	it("evaluates random condition with probability 1.0", function()
		local def = { probability = 1.0 }
		assert.is_true(conditions.random(def, {}))
	end)

	it("evaluates random condition with probability 0.0", function()
		local def = { probability = 0.0 }
		assert.is_false(conditions.random(def, {}))
	end)

	it("evaluates random condition with invalid probability as false", function()
		local def = { probability = nil }
		assert.is_false(conditions.random(def, {}))
	end)

	it("fractional random without rng is false (replay-safe fallback)", function()
		assert.is_false(conditions.random({ probability = 0.37 }, {}))
		assert.is_false(conditions.random({ probability = 0.37 }, nil))
	end)

	it("fractional random uses state.rng deterministically", function()
		local def = { probability = 0.37 }
		local s1 = { rng = { seed = 94211 } }
		local s2 = { rng = { seed = 94211 } }
		assert.are.equal(conditions.random(def, s1), conditions.random(def, s2))
	end)

	it("evaluates empty conditions array as true (pass-through)", function()
		assert.is_true(conditions.eval_all({}, {}))
	end)

	it("evaluates nil conditions as true (pass-through)", function()
		assert.is_true(conditions.eval_all(nil, {}))
	end)

	it("evaluates single always condition as true", function()
		local cond_array = { { condition_name = "always" } }
		assert.is_true(conditions.eval_all(cond_array, {}))
	end)

	it("evaluates single never condition as false", function()
		local cond_array = { { condition_name = "never" } }
		assert.is_false(conditions.eval_all(cond_array, {}))
	end)

	it("short-circuits on first false condition", function()
		local cond_array = {
			{ condition_name = "always" },
			{ condition_name = "never" },
			{ condition_name = "always" },
		}
		assert.is_false(conditions.eval_all(cond_array, {}))
	end)

	it("evaluates all conditions as true when all pass", function()
		local cond_array = {
			{ condition_name = "always" },
			{ condition_name = "always" },
		}
		assert.is_true(conditions.eval_all(cond_array, {}))
	end)

	it("returns true for unknown condition name (fail-safe)", function()
		local cond_array = { { condition_name = "unknown_condition" } }
		assert.is_true(conditions.eval_all(cond_array, {}))
	end)

	it("evaluates single condition by name", function()
		assert.is_true(conditions.eval("always", {}))
		assert.is_false(conditions.eval("never", {}))
	end)

	it("returns true for unknown condition by name (fail-safe)", function()
		assert.is_true(conditions.eval("unknown", {}))
	end)
end)
