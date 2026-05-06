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

	it("dispatches callback for matching trigger across both slots", function()
		local player = {
			stances = {
				fixed = { "stance_point" },
				swappable = { "stance_mult" },
			},
		}
		local seen = {}
		stances.dispatch_trigger(player, "TURN_START", function(stance_id, stance_def)
			seen[#seen + 1] = { id = stance_id, trigger = stance_def.trigger }
		end)
		assert.are.same({
			{ id = "stance_point", trigger = "TURN_START" },
			{ id = "stance_mult", trigger = "TURN_START" },
		}, seen)
	end)

	it("does not dispatch unknown stance ids", function()
		local player = {
			stances = {
				fixed = { "stance_missing" },
				swappable = {},
			},
		}
		local calls = 0
		stances.dispatch_trigger(player, "TURN_START", function()
			calls = calls + 1
		end)
		assert.are.equal(0, calls)
	end)

	it("does not dispatch when no stance matches trigger", function()
		local player = {
			stances = {
				fixed = { "stance_point" },
				swappable = {},
			},
		}
		local calls = 0
		stances.dispatch_trigger(player, "ON_CAPTURE", function()
			calls = calls + 1
		end)
		assert.are.equal(0, calls)
	end)
end)
