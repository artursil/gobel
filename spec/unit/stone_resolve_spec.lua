local stone_resolve = require("objects.stone_resolve")
local content = require("content")
local ObjectInstance = require("single_game.resolver.ObjectInstance")

describe("stone_resolve.apply_effect_deltas", function()
	local base_effects = {
		{
			effect_name = "add_points",
			action = "on_play",
			phase = "points",
			value = 2,
			priority = 10,
		},
		{
			effect_name = "add_mult",
			action = "on_play",
			phase = "mult",
			value = 1,
			priority = 10,
		},
	}

	it("adds delta when effect_name matches", function()
		local out = stone_resolve.apply_effect_deltas(base_effects, {
			add_points = { delta = 1 },
		})
		assert.are.equal(3, out[1].value)
		assert.are.equal(1, out[2].value)
	end)

	it("ignores delta keys that do not match an effect_name", function()
		local out = stone_resolve.apply_effect_deltas(base_effects, {
			add_mult = { delta = 5 },
		})
		assert.are.equal(2, out[1].value)
		assert.are.equal(6, out[2].value)
	end)

	it("applies delta to only one effect when multiple are present", function()
		local out = stone_resolve.apply_effect_deltas(base_effects, {
			add_mult = { delta = 2 },
		})
		assert.are.equal(2, out[1].value)
		assert.are.equal(3, out[2].value)
	end)

	it("does not mutate the original effect rows", function()
		stone_resolve.apply_effect_deltas(base_effects, {
			add_points = { delta = 1 },
		})
		assert.are.equal(2, base_effects[1].value)
	end)
end)

describe("content.resolve_stone", function()
	it("returns base def for string id", function()
		local base = content.get_stone("stone_power")
		local resolved = content.resolve_stone("stone_power")
		assert.are.equal(base, resolved)
		assert.are.equal(2, resolved.effects[1].value)
	end)

	it("level 2 stone_power adds cumulative placement points delta", function()
		local resolved = content.resolve_stone({ def_id = "stone_power", level = 2 })
		assert.are.equal(3, resolved.effects[1].value)
		assert.are.equal(2, resolved._level)
	end)

	it("level 3 without tier 3 entry keeps level 2 cumulative bonuses", function()
		local resolved = content.resolve_stone({ def_id = "stone_power", level = 3 })
		assert.are.equal(3, resolved.effects[1].value)
		assert.are.equal(3, resolved._level)
	end)

	it("clamps level to max_level on the stone def", function()
		local resolved = content.resolve_stone({ def_id = "stone_power", level = 99 })
		assert.are.equal(3, resolved._level)
	end)
end)

describe("ObjectInstance.upgrade", function()
	it("stops at stone def max_level", function()
		local instance = ObjectInstance.new("p1", "stone_power", "stone", "black", "starter", {})
		instance.level = 1
		assert.is_true(ObjectInstance.upgrade(instance))
		assert.are.equal(2, instance.level)
		assert.is_true(ObjectInstance.upgrade(instance))
		assert.are.equal(3, instance.level)
		assert.is_false(ObjectInstance.upgrade(instance))
		assert.are.equal(3, instance.level)
	end)
end)
