require("spec.test_helper")

local config = require("config")
local stance_order = require("single_game.resolver.stance_order")

local function state_with_stances(black_fixed, white_fixed)
	return {
		players = {
			black = { stances = { fixed = black_fixed or {}, swappable = {} } },
			white = { stances = { fixed = white_fixed or {}, swappable = {} } },
		},
		temporary_stances = {},
	}
end

describe("stance_order canonical vs derived", function()
	it("black and white panel slot_index are independent (no global merge off-by-one)", function()
		local s = state_with_stances(
			{ "stance_point", "stance_mult" },
			{ "stance_point" }
		)
		local o = stance_order.flatten_stances_for_resolve(s)
		assert.are.equal(1, o[1].slot_index)
		assert.are.equal(config.OWNER_BLACK, o[1].owner)
		assert.are.equal(2, o[2].slot_index)
		assert.are.equal(1, o[3].slot_index)
		assert.are.equal(config.OWNER_WHITE, o[3].owner)
	end)
end)
