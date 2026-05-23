require("spec.test_helper")

local config = require("config")
local pattern_proximity = require("ai.heuristics.pattern_proximity")
local spec_helper = require("spec.spec_helper")

describe("ai.heuristics.pattern_proximity", function()
	it("moves_to_complete_x is 0 when X already complete", function()
		local b = spec_helper.parse_board_ascii_kinds({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . X . X . . .",
			". . . . X . . . .",
			". . . X . X . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			X = { color = config.STONE_BLACK, kind = "x_stone" },
		})
		assert.are.equal(0, pattern_proximity.moves_to_complete_x(b, config.STONE_BLACK, 2))
	end)

	it("moves_to_complete_x is 1 when one diagonal arm missing", function()
		local b = spec_helper.parse_board_ascii_kinds({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . X . X . . .",
			". . . . X . . . .",
			". . . X . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			X = { color = config.STONE_BLACK, kind = "x_stone" },
		})
		assert.are.equal(1, pattern_proximity.moves_to_complete_x(b, config.STONE_BLACK, 2))
	end)

	it("is_blocking_cell detects opponent + threat", function()
		local b = spec_helper.parse_board_ascii_kinds({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . P . . . .",
			". . . P P . . . .",
			". . . . P . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, {
			P = { color = config.STONE_WHITE, kind = "plus_stone" },
		})
		assert.is_true(pattern_proximity.is_blocking_cell(b, 5, 6, config.STONE_WHITE, "plus", 2))
		assert.is_false(pattern_proximity.is_blocking_cell(b, 1, 1, config.STONE_WHITE, "plus", 2))
	end)
end)
