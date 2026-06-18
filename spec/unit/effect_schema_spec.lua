require("spec.test_helper")

local Effect = require("objects.effects_conditions.EffectSchema")
local effect_enums = require("objects.effects_conditions.scheduling")

describe("T-202 Effect schema runtime", function()
	it("creates effect instance with action and phase", function()
		local effect_def = {
			effect_name = "add_points",
			action = effect_enums.ACTION.on_card,
			phase = effect_enums.PHASE.points,
			priority = 10,
			value = 5,
		}
		local effect = Effect.new(effect_def)

		assert.are.equal("add_points", effect.effect_name)
		assert.are.equal(effect_enums.ACTION.on_card, effect.action)
		assert.are.equal(effect_enums.PHASE.points, effect.phase)
		assert.are.equal(10, effect.priority)
		assert.are.equal(5, effect.value)
	end)

	it("validates action/phase effect", function()
		local effect_def = {
			effect_name = "add_points",
			action = effect_enums.ACTION.on_play,
			phase = effect_enums.PHASE.points,
		}
		local valid, err = Effect.validate(effect_def)
		assert.is_true(valid)
		assert.is_nil(err)
	end)

	it("rejects legacy macro field", function()
		local effect_def = {
			effect_name = "add_points",
			macro = "playing_stones",
			phase = "points",
		}
		local valid, err = Effect.validate(effect_def)
		assert.is_false(valid)
		assert.matches("removed field macro", err)
	end)

	it("rejects invalid effect_name", function()
		local effect_def = {
			effect_name = nil,
			action = effect_enums.ACTION.on_card,
			phase = effect_enums.PHASE.points,
		}
		local valid, err = Effect.validate(effect_def)
		assert.is_false(valid)
		assert.is_not_nil(err)
	end)

	it("applies to phase correctly", function()
		local effect = Effect.new({
			effect_name = "test",
			action = effect_enums.ACTION.on_card,
			phase = effect_enums.PHASE.points,
		})
		assert.is_true(Effect.applies_to_phase(effect, effect_enums.PHASE.points))
		assert.is_false(Effect.applies_to_phase(effect, effect_enums.PHASE.mult))
	end)

	it("gets effect priority", function()
		local effect = Effect.new({
			effect_name = "test",
			action = effect_enums.ACTION.on_card,
			phase = effect_enums.PHASE.points,
			priority = 20,
		})
		assert.are.equal(20, Effect.get_priority(effect))
	end)

	it("gets effect value with scope multiplier", function()
		local effect = Effect.new({
			effect_name = "test",
			action = effect_enums.ACTION.on_card,
			phase = effect_enums.PHASE.points,
			value = 10,
		})
		assert.are.equal(10, Effect.get_value(effect, 1.0))
		assert.are.equal(20, Effect.get_value(effect, 2.0))
	end)

	it("defaults priority to 10", function()
		local effect = Effect.new({
			effect_name = "test",
			action = effect_enums.ACTION.on_card,
			phase = effect_enums.PHASE.points,
		})
		assert.are.equal(10, effect.priority)
	end)

	it("defaults scope to game", function()
		local effect = Effect.new({
			effect_name = "test",
			action = effect_enums.ACTION.on_card,
			phase = effect_enums.PHASE.points,
		})
		assert.are.equal("game", effect.scope)
	end)

	it("rejects duplicate kwargs keys across conditions", function()
		local effect_def = {
			effect_name = "test_effect",
			action = effect_enums.ACTION.on_play,
			phase = effect_enums.PHASE.points,
			conditions = {
				{ condition_name = "stance_owner_is_current_turn", kwargs_keys = { "blocks" } },
				{ condition_name = "wall_part_of_wall" },
			},
		}
		local valid, err = Effect.validate(effect_def)
		assert.is_false(valid)
		assert.is_not_nil(err)
		assert.matches("Duplicate kwargs key .-blocks", err)
		assert.matches("conditions #1 and #2", err)
	end)
end)
