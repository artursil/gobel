require("spec.test_helper")

local energy = require("energy")
local P = require("spec.parameters_helper")

--- @param current number
--- @param max number|nil
--- @return table
local function new_player(current, max)
	max = max or P.energy_max_default()
	return {
		energy = current,
		energy_max = max,
		resources = {
			energy_current = current,
			energy_max = max,
		},
	}
end

--- Player with stale resources.energy_current to guard against adopting buried resource energy.
--- @param energy number
--- @param resource_current number
--- @param max number|nil
--- @return table
local function new_divergent_player(energy, resource_current, max)
	max = max or P.energy_max_default()
	return {
		energy = energy,
		energy_max = max,
		resources = {
			energy_current = resource_current,
			energy_max = max,
		},
	}
end

describe("T-011 energy", function()
	it("refreshes current energy to max", function()
		local player = new_player(0)
		energy.refresh(player)
		assert.are.equal(P.energy_max_default(), player.energy)
	end)

	it("spends available energy", function()
		local player = new_player(P.energy_max_default())
		local ok = energy.spend(player, 2)
		assert.is_true(ok)
		assert.are.equal(1, player.energy)
	end)

	it("rejects spend when energy is insufficient", function()
		local player = new_player(1)
		local ok = energy.spend(player, 2)
		assert.is_false(ok)
		assert.are.equal(1, player.energy)
	end)

	it("rejects negative spend amounts", function()
		local player = new_player(2)
		local ok = energy.spend(player, -1)
		assert.is_false(ok)
		assert.are.equal(2, player.energy)
	end)

	it("allows spending exactly current energy", function()
		local player = new_player(2)
		assert.is_true(energy.can_spend(player, 2))
	end)

	it("gains energy without exceeding energy_max", function()
		local player = new_player(1)
		energy.gain(player, 1)
		assert.are.equal(2, player.energy)
	end)

	it("clamps gain at energy_max", function()
		local player = new_player(2)
		energy.gain(player, 5)
		assert.are.equal(P.energy_max_default(), player.energy)
	end)

	it("ignores non-positive gain amounts", function()
		local player = new_player(2)
		energy.gain(player, 0)
		assert.are.equal(2, player.energy)
		energy.gain(player, -1)
		assert.are.equal(2, player.energy)
	end)

	it("syncs resources.energy_current after spend", function()
		local player = new_player(P.energy_max_default())
		energy.spend(player, 1)
		assert.are.equal(player.energy, player.resources.energy_current)
	end)

	it("syncs resources.energy_current after gain", function()
		local player = new_player(1)
		energy.gain(player, 1)
		assert.are.equal(player.energy, player.resources.energy_current)
	end)

	it("syncs resources after refresh", function()
		local player = new_player(0)
		energy.refresh(player)
		assert.are.equal(player.energy, player.resources.energy_current)
		assert.are.equal(player.energy_max, player.resources.energy_max)
	end)

	it("uses player.energy when resources.energy_current diverges", function()
		local max = P.energy_max_default()
		local stale = max + 10

		local can_spend_player = new_divergent_player(1, stale, max)
		assert.is_true(energy.can_spend(can_spend_player, 1))
		assert.is_false(energy.can_spend(can_spend_player, 2))

		local spend_player = new_divergent_player(2, 0, max)
		assert.is_true(energy.spend(spend_player, 1))
		assert.are.equal(1, spend_player.energy)
		assert.are.equal(1, spend_player.resources.energy_current)

		local gain_player = new_divergent_player(1, stale, max)
		energy.gain(gain_player, 1)
		assert.are.equal(2, gain_player.energy)
		assert.are.equal(2, gain_player.resources.energy_current)

		local refresh_player = new_divergent_player(0, stale, max)
		energy.refresh(refresh_player)
		assert.are.equal(max, refresh_player.energy)
		assert.are.equal(max, refresh_player.resources.energy_current)
	end)
end)
