require("spec.test_helper")

local config = require("config")
local features = require("ai.board_analysis.features")
local spec_helper = require("spec.spec_helper")

describe("ai.board_analysis.features", function()
	it("build returns non-negative territory counts on empty board", function()
		local b = require("board").new()
		local f = features.build(b, nil, config.OWNER_BLACK, "regional", config.STONE_BLACK)
		assert.is_true(f.territory_owned_me >= 0)
		assert.is_true(f.territory_owned_opp >= 0)
		assert.is_true(f.territory_contested >= 0)
	end)

	it("contested increases when both sides influence empty cells", function()
		local rows = {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . B . . . . .",
			". . . . . . . W .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}
		local b = spec_helper.parse_board_ascii(rows)
		local f = features.build(b, nil, config.OWNER_BLACK, "regional", config.STONE_BLACK)
		assert.is_true(f.territory_contested >= 1)
	end)
end)
