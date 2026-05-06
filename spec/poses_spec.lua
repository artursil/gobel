require("spec.test_helper")

local stances = require("stances")

describe("T-014 stances", function()
	it("returns active stance ids from fixed and swappable slots", function()
		local player = {
			stances = {
				fixed = { "stance_point" },
				swappable = { "stance_mult" },
			},
		}
		assert.are.same({ "stance_point", "stance_mult" }, stances.active_stance_ids(player))
	end)

	it("returns empty list when no stances active", function()
		local player = {
			stances = {
				fixed = {},
				swappable = {},
			},
		}
		assert.are.same({}, stances.active_stance_ids(player))
	end)

	it("does not return unknown stance ids", function()
		local player = {
			stances = {
				fixed = { "stance_missing" },
				swappable = {},
			},
		}
		assert.are.same({ "stance_missing" }, stances.active_stance_ids(player))
	end)
end)
