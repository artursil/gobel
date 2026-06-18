require("spec.test_helper")

local effects = require("objects.effects_conditions.effects")
local conditions = require("objects.effects_conditions.conditions")
local match_state = require("match_state")
local P = require("spec.parameters_helper")

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
		assert.are.equal("add_points", resolved.effect_name)
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
		assert.are.equal("add_mult", resolved.effect_name)
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
		assert.are.equal("distance_bonus", resolved.effect_name)
		assert.are.equal("territory", resolved.phase)
		assert.are.equal("distance", resolved.territory_step)
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

	it("resolves add_energy effect", function()
		local effect_def = {
			effect_name = "add_energy",
			action = "on_play",
			phase = "points",
			value = P.stone.energy_stone_gain,
			priority = 10,
		}
		local resolved = effects.resolve(effect_def)
		assert.is_not_nil(resolved)
		assert.are.equal("add_energy", resolved.effect_name)
		assert.are.equal("points", resolved.phase)
		assert.are.equal(P.stone.energy_stone_gain, resolved.value)
		assert.are.equal(10, resolved.priority)
		assert.is_not_nil(resolved.apply)
	end)

	it("applies add_energy effect to player energy", function()
		local state = match_state.new_match("pvp", 1)
		local player = state.players.black
		player.energy = 0
		player.energy_max = P.energy_max_default()
		local effect_def = {
			effect_name = "add_energy",
			value = P.stone.energy_stone_gain,
		}
		local resolved = effects.resolve(effect_def)
		resolved.apply(state, "B")
		assert.are.equal(P.stone.energy_stone_gain, player.energy)
		assert.are.equal(player.energy, player.resources.energy_current)
	end)

	it("clamps add_energy at player energy_max", function()
		local state = match_state.new_match("pvp", 2)
		local player = state.players.black
		player.energy = P.energy_max_default()
		player.energy_max = P.energy_max_default()
		local effect_def = {
			effect_name = "add_energy",
			value = P.stone.energy_stone_gain,
		}
		local resolved = effects.resolve(effect_def)
		resolved.apply(state, "B")
		assert.are.equal(P.energy_max_default(), player.energy)
		assert.are.equal(player.energy, player.resources.energy_current)
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

	it("resolves wall_stone", function()
		local wall = effects.resolve({ effect_name = "wall_stone", phase = "points" })
		assert.are.equal("wall_stone", wall.effect_name)
	end)

	it("preserves conditions in resolved effect", function()
		local effect_def = {
			effect_name = "add_points",
			value = 1,
			priority = 10,
			conditions = {
				{ condition_name = "round_number_exactly", value = 1 },
			},
		}
		local resolved = effects.resolve(effect_def)
		assert.is_not_nil(resolved.conditions)
		assert.are.equal(1, #resolved.conditions)
	end)
end)
