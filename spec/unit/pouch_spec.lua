local helper = require("spec.test_helper")
local pouch = require("pouch")

describe("T-012 pouch", function()
	it("draws a stone and updates remaining count", function()
		local state = { ids = { "s1", "s2" } }
		local drawn = pouch.draw(state)
		assert.are.equal("s2", drawn)
		assert.are.equal(1, pouch.remaining_count(state))
	end)

	it("returns nil when drawing from an empty pouch", function()
		local state = { ids = {} }
		local drawn = pouch.draw(state)
		assert.is_nil(drawn)
		assert.are.equal(0, pouch.remaining_count(state))
	end)

	it("returns deterministic preview ordering", function()
		local state = { ids = { "s1", "s2", "s3" } }
		local next_id = pouch.peek_next(state)
		local many = pouch.peek_many(state, 2)
		assert.are.equal("s3", next_id)
		assert.are.same({ "s3", "s2" }, many)
	end)

	it("initializes shuffled pouch deterministically for a deterministic rng", function()
		local initial = { "a", "b", "c", "d" }
		local shuffled = pouch.shuffle_init(initial, helper.rng_always_one)
		assert.are.same({ "b", "c", "d", "a" }, shuffled.ids)
		assert.are.same({ "a", "b", "c", "d" }, initial)
	end)
end)
