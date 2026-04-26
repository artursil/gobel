require("spec.test_helper")

local poses = require("poses")

describe("T-014 poses", function()
	it("returns active pose ids from fixed and swappable slots", function()
		local player = {
			poses = {
				fixed = { "pose_point_stance" },
				swappable = { "pose_mult_stance" },
			},
		}
		assert.are.same({ "pose_point_stance", "pose_mult_stance" }, poses.active_pose_ids(player))
	end)

	it("dispatches callback for matching trigger across both slots", function()
		local player = {
			poses = {
				fixed = { "pose_point_stance" },
				swappable = { "pose_mult_stance" },
			},
		}
		local seen = {}
		poses.dispatch_trigger(player, "TURN_START", function(pose_id, pose_def)
			seen[#seen + 1] = { id = pose_id, trigger = pose_def.trigger }
		end)
		assert.are.same({
			{ id = "pose_point_stance", trigger = "TURN_START" },
			{ id = "pose_mult_stance", trigger = "TURN_START" },
		}, seen)
	end)

	it("does not dispatch unknown pose ids", function()
		local player = {
			poses = {
				fixed = { "pose_missing" },
				swappable = {},
			},
		}
		local calls = 0
		poses.dispatch_trigger(player, "TURN_START", function()
			calls = calls + 1
		end)
		assert.are.equal(0, calls)
	end)

	it("does not dispatch when no pose matches trigger", function()
		local player = {
			poses = {
				fixed = { "pose_point_stance" },
				swappable = {},
			},
		}
		local calls = 0
		poses.dispatch_trigger(player, "ON_CAPTURE", function()
			calls = calls + 1
		end)
		assert.are.equal(0, calls)
	end)
end)
