require("spec.test_helper")

local energy = require("energy")

describe("T-011 energy", function()
	it("refreshes current energy to max", function()
		local resources = { energy_current = 0, energy_max = 3 }
		energy.refresh(resources)
		assert.are.equal(3, resources.energy_current)
	end)

	it("spends available energy", function()
		local resources = { energy_current = 3, energy_max = 3 }
		local ok = energy.spend(resources, 2)
		assert.is_true(ok)
		assert.are.equal(1, resources.energy_current)
	end)

	it("rejects spend when energy is insufficient", function()
		local resources = { energy_current = 1, energy_max = 3 }
		local ok = energy.spend(resources, 2)
		assert.is_false(ok)
		assert.are.equal(1, resources.energy_current)
	end)

	it("rejects negative spend amounts", function()
		local resources = { energy_current = 2, energy_max = 3 }
		local ok = energy.spend(resources, -1)
		assert.is_false(ok)
		assert.are.equal(2, resources.energy_current)
	end)

	it("allows spending exactly current energy", function()
		local resources = { energy_current = 2, energy_max = 3 }
		assert.is_true(energy.can_spend(resources, 2))
	end)
end)
