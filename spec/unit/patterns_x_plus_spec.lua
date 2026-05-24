require("spec.test_helper")

local board = require("board")
local config = require("config")
local patterns = require("patterns")
local shape_patterns = require("game.patterns.shape_patterns")
local spec_helper = require("spec.spec_helper")
local P = require("spec.parameters_helper")

local X_MAP = {
	X = { color = config.STONE_BLACK, kind = "x_stone" },
	B = { color = config.STONE_BLACK, kind = "stone_basic" },
}

local PLUS_MAP = {
	P = { color = config.STONE_WHITE, kind = "plus_stone" },
}

describe("patterns X and + detection", function()
	it("detects minimal X with tier 1 and has_x_stone", function()
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
		}, X_MAP)
		local found = patterns.detect_x_patterns(b, config.STONE_BLACK)
		assert.are.equal(1, #found)
		assert.is_true(found[1].has_x_stone)
		assert.are.equal(1, found[1].tier)
		assert.are.equal(P.stone.x_pattern_tiers[1], found[1].stone_count)
	end)

	it("detects tier 2 X when arms extend", function()
		local rows = {
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . X . X . . .",
			". . . . X . . . .",
			". . . X . X . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}
		local b = spec_helper.parse_board_ascii_kinds(rows, X_MAP)
		b[3][3] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[3][7] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[7][3] = board.make_stone(config.STONE_BLACK, "stone_basic")
		b[7][7] = board.make_stone(config.STONE_BLACK, "stone_basic")
		local found = patterns.detect_x_patterns(b, config.STONE_BLACK)
		assert.are.equal(1, #found)
		assert.are.equal(2, found[1].tier)
		assert.is_true(found[1].stone_count >= P.stone.x_pattern_tiers[2])
	end)

	it("detects plus pattern with has_plus_stone", function()
		local b = spec_helper.parse_board_ascii_kinds({
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . P . . . .",
			". . . P P P . . .",
			". . . . P . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
			". . . . . . . . .",
		}, PLUS_MAP)
		local found = patterns.detect_plus_patterns(b, config.STONE_WHITE)
		assert.are.equal(1, #found)
		assert.is_true(found[1].has_plus_stone)
		assert.are.equal(1, found[1].tier)
	end)

	it("x_mult_factor_for_tier matches configured factor raised to tier", function()
		for tier = 1, 3 do
			assert.are.equal(P.x_mult_tier_product(tier), shape_patterns.x_mult_factor_for_tier(tier))
		end
	end)

	it("plus_mult_bonus_for_tier adds configured bonus per tier", function()
		for tier = 1, 3 do
			assert.are.equal(P.stone.plus_stone_mult_add * tier, shape_patterns.plus_mult_bonus_for_tier(tier))
		end
	end)

	it("count_x_stones_in_diagonal_patterns counts x_stone cells in qualifying X", function()
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
		}, X_MAP)
		assert.are.equal(P.stone.x_pattern_tiers[1], patterns.count_x_stones_in_diagonal_patterns(b, config.STONE_BLACK))
	end)
end)
