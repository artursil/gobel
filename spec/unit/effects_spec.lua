require("spec.test_helper")

local effects = require("objects.effects")
local conditions = require("objects.conditions")

describe("T-100 effects system", function()
	it("resolves add_points effect", function()
		local effect_def = {
			effect_name = "add_points",
			phase = "points",
			value = 3,
			priority = 10,
		}
		local resolved = effects.resolve(effect_def)
		assert.is_not_nil(resolved)
		assert.are.equal("ADD_POINTS", resolved.type)
		assert.are.equal("points", resolved.phase)
		assert.are.equal(3, resolved.value)
		assert.are.equal(10, resolved.priority)
		assert.is_not_nil(resolved.apply)
	end)

	it("resolves add_mult effect", function()
		local effect_def = {
			effect_name = "add_mult",
			phase = "mult",
			value = 2,
			priority = 15,
		}
		local resolved = effects.resolve(effect_def)
		assert.is_not_nil(resolved)
		assert.are.equal("ADD_MULT", resolved.type)
		assert.are.equal("mult", resolved.phase)
		assert.are.equal(2, resolved.value)
		assert.are.equal(15, resolved.priority)
		assert.is_not_nil(resolved.apply)
	end)

	it("resolves distance_bonus effect", function()
		local effect_def = {
			effect_name = "distance_bonus",
			value = 1,
			priority = 10,
		}
		local resolved = effects.resolve(effect_def)
		assert.is_not_nil(resolved)
		assert.are.equal("DISTANCE_BONUS", resolved.type)
		assert.are.equal("distance", resolved.phase)
		assert.are.equal(1, resolved.value)
	end)

	it("returns nil for unknown effect", function()
		local effect_def = {
			effect_name = "unknown_effect",
			value = 1,
		}
		local resolved = effects.resolve(effect_def)
		assert.is_nil(resolved)
	end)

	it("applies add_points effect to state", function()
		local state = {
			scores = {
				points = { B = 0, W = 0 },
			},
		}
		local effect_def = {
			effect_name = "add_points",
			value = 5,
		}
		local resolved = effects.resolve(effect_def)
		resolved.apply(state, "B")
		assert.are.equal(5, state.scores.points.B)
		assert.are.equal(0, state.scores.points.W)
	end)

	it("applies add_mult effect to state", function()
		local state = {
			scores = {
				plus_mult = { B = 1, W = 1 },
			},
		}
		local effect_def = {
			effect_name = "add_mult",
			value = 3,
		}
		local resolved = effects.resolve(effect_def)
		resolved.apply(state, "W")
		assert.are.equal(1, state.scores.plus_mult.B)
		assert.are.equal(4, state.scores.plus_mult.W)
	end)

	it("resolves pattern_x_mult and pattern_plus_mult", function()
		assert.is_not_nil(effects.resolve({ effect_name = "pattern_x_mult", phase = "mult" }))
		assert.is_not_nil(effects.resolve({ effect_name = "pattern_plus_mult", phase = "mult" }))
	end)

	it("resolves wall_stone and wall_stone_other", function()
		local other = effects.resolve({ effect_name = "wall_stone_other", phase = "points", value = 2 })
		local wall = effects.resolve({ effect_name = "wall_stone", phase = "points", value = 2 })
		assert.are.equal("WALL_STONE_OTHER", other.type)
		assert.are.equal("WALL_STONE", wall.type)
	end)

	it("preserves conditions in resolved effect", function()
		local effect_def = {
			effect_name = "add_points",
			value = 1,
			priority = 10,
			conditions = {
				{ condition_name = "always" },
			},
		}
		local resolved = effects.resolve(effect_def)
		assert.is_not_nil(resolved.conditions)
		assert.are.equal(1, #resolved.conditions)
	end)
end)
