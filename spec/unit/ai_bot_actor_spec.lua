require("spec.test_helper")

local config = require("config")
local controller = require("ai.controller")
local match_view = require("ai.adapters.match_view")

describe("ai bot actor", function()
	it("for_bot and controller agree with config.AI_COLOR", function()
		local expected = config.AI_COLOR == config.STONE_WHITE and "white" or "black"
		assert.are.equal(expected, controller.bot_actor())
		assert.are.equal(expected, match_view.bot_actor())
	end)
end)
