require("spec.test_helper")

local economy = require("economy")

describe("T-010 economy", function()
	it("reads money value", function()
		local resources = { money = 7 }
		assert.are.equal(7, economy.get(resources))
	end)

	it("gains non-negative money", function()
		local resources = { money = 3 }
		local ok = economy.gain(resources, 4)
		assert.is_true(ok)
		assert.are.equal(7, resources.money)
	end)

	it("rejects negative gain", function()
		local resources = { money = 3 }
		local ok = economy.gain(resources, -1)
		assert.is_false(ok)
		assert.are.equal(3, resources.money)
	end)

	it("spends without going below zero", function()
		local resources = { money = 5 }
		local ok = economy.spend(resources, 5)
		assert.is_true(ok)
		assert.are.equal(0, resources.money)
	end)

	it("rejects spend when funds are insufficient", function()
		local resources = { money = 2 }
		local ok = economy.spend(resources, 3)
		assert.is_false(ok)
		assert.are.equal(2, resources.money)
	end)

	it("rejects negative spend amounts", function()
		local resources = { money = 2 }
		local ok = economy.spend(resources, -1)
		assert.is_false(ok)
		assert.are.equal(2, resources.money)
	end)
end)
