require("spec.test_helper")

local Effect = require("single_game.resolver.Effect")

describe("T-202 Effect schema runtime", function()
	it("creates effect instance with all schema fields", function()
		local effect_def = {
			effect_name = "add_points",
			phase = "points",
			priority = 10,
			value = 5,
		}
		local effect = Effect.new(effect_def)

		assert.are.equal("add_points", effect.effect_name)
		assert.are.equal("points", effect.phase)
		assert.are.equal(10, effect.priority)
		assert.are.equal(5, effect.value)
		assert.is_not_nil(effect.params)
		assert.are.equal("game", effect.scope)
	end)

	it("validates valid effect", function()
		local effect_def = {
			effect_name = "add_points",
			phase = "points",
		}
		local valid, err = Effect.validate(effect_def)
		assert.is_true(valid)
		assert.is_nil(err)
	end)

	it("rejects invalid effect_name", function()
		local effect_def = {
			effect_name = nil,
			phase = "points",
		}
		local valid, err = Effect.validate(effect_def)
		assert.is_false(valid)
		assert.is_not_nil(err)
	end)

	it("applies to phase correctly", function()
		local effect = Effect.new({ effect_name = "test", phase = "points" })
		assert.is_true(Effect.applies_to_phase(effect, "points"))
		assert.is_false(Effect.applies_to_phase(effect, "mult"))
	end)

	it("gets effect priority", function()
		local effect = Effect.new({ effect_name = "test", phase = "points", priority = 20 })
		assert.are.equal(20, Effect.get_priority(effect))
	end)

	it("gets effect value with scope multiplier", function()
		local effect = Effect.new({ effect_name = "test", phase = "points", value = 10 })
		assert.are.equal(10, Effect.get_value(effect, 1.0))
		assert.are.equal(20, Effect.get_value(effect, 2.0))
		assert.are.equal(15, Effect.get_value(effect, 1.5))
	end)

	it("defaults priority to 10", function()
		local effect = Effect.new({ effect_name = "test", phase = "points" })
		assert.are.equal(10, effect.priority)
	end)

	it("defaults scope to game", function()
		local effect = Effect.new({ effect_name = "test", phase = "points" })
		assert.are.equal("game", effect.scope)
	end)
end)
