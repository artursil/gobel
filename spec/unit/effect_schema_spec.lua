require("spec.test_helper")

local Effect = require("single_game.resolver.Effect")

describe("T-202 Effect schema runtime", function()
	it("creates effect instance with macro and sub", function()
		local effect_def = {
			effect_name = "add_points",
			macro = "playing_cards",
			sub = "points",
			priority = 10,
			value = 5,
		}
		local effect = Effect.new(effect_def)

		assert.are.equal("add_points", effect.effect_name)
		assert.are.equal("playing_cards", effect.macro)
		assert.are.equal("points", effect.sub)
		assert.are.equal(10, effect.priority)
		assert.are.equal(5, effect.value)
	end)

	it("validates macro/sub effect", function()
		local effect_def = {
			effect_name = "add_points",
			macro = "playing_stones",
			sub = "points",
		}
		local valid, err = Effect.validate(effect_def)
		assert.is_true(valid)
		assert.is_nil(err)
	end)

	it("rejects invalid effect_name", function()
		local effect_def = {
			effect_name = nil,
			macro = "playing_cards",
			sub = "points",
		}
		local valid, err = Effect.validate(effect_def)
		assert.is_false(valid)
		assert.is_not_nil(err)
	end)

	it("applies to sub correctly", function()
		local effect = Effect.new({ effect_name = "test", macro = "playing_cards", sub = "points" })
		assert.is_true(Effect.applies_to_phase(effect, "points"))
		assert.is_false(Effect.applies_to_phase(effect, "mult"))
	end)

	it("gets effect priority", function()
		local effect = Effect.new({ effect_name = "test", macro = "playing_cards", sub = "points", priority = 20 })
		assert.are.equal(20, Effect.get_priority(effect))
	end)

	it("gets effect value with scope multiplier", function()
		local effect = Effect.new({ effect_name = "test", macro = "playing_cards", sub = "points", value = 10 })
		assert.are.equal(10, Effect.get_value(effect, 1.0))
		assert.are.equal(20, Effect.get_value(effect, 2.0))
	end)

	it("defaults priority to 10", function()
		local effect = Effect.new({ effect_name = "test", macro = "playing_cards", sub = "points" })
		assert.are.equal(10, effect.priority)
	end)

	it("defaults scope to game", function()
		local effect = Effect.new({ effect_name = "test", macro = "playing_cards", sub = "points" })
		assert.are.equal("game", effect.scope)
	end)
end)
