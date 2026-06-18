require("spec.test_helper")

local test_helper = require("spec.test_helper")
local board = require("board")
local config = require("config")
local conditions = require("objects.effects_conditions.conditions")
local capture_stone_supplemental_target = require("objects.effects_conditions.conditions.capture_stone_supplemental_target")

local function passing_round_condition()
	return { condition_name = "round_number_exactly", value = 1 }
end

local function failing_round_condition()
	return { condition_name = "round_number_exactly", value = 99 }
end

describe("T-101 conditions system", function()
	it("evaluates empty conditions array as true (pass-through)", function()
		assert.is_true(conditions.eval_all({}, {}))
	end)

	it("evaluates nil conditions as true (pass-through)", function()
		assert.is_true(conditions.eval_all(nil, {}))
	end)

	it("evaluates single passing condition as true", function()
		local cond_array = { passing_round_condition() }
		assert.is_true(conditions.eval_all(cond_array, { round_number = 1 }))
	end)

	it("evaluates single failing condition as false", function()
		local cond_array = { failing_round_condition() }
		assert.is_false(conditions.eval_all(cond_array, { round_number = 1 }))
	end)

	it("short-circuits on first false condition", function()
		local cond_array = {
			passing_round_condition(),
			failing_round_condition(),
			passing_round_condition(),
		}
		assert.is_false(conditions.eval_all(cond_array, { round_number = 1 }))
	end)

	it("evaluates all conditions as true when all pass", function()
		local cond_array = {
			passing_round_condition(),
			passing_round_condition(),
		}
		assert.is_true(conditions.eval_all(cond_array, { round_number = 1 }))
	end)

	it("returns true for unknown condition name (fail-safe)", function()
		local cond_array = { { condition_name = "unknown_condition" } }
		assert.is_true(conditions.eval_all(cond_array, {}))
	end)

	it("returns true for unknown condition by name (fail-safe)", function()
		assert.is_true(conditions.eval("unknown", {}))
	end)

	it("evaluates round_number_exactly", function()
		assert.is_true(conditions.eval({ condition_name = "round_number_exactly", value = 2 }, { round_number = 2 }))
		assert.is_false(conditions.eval({ condition_name = "round_number_exactly", value = 1 }, { round_number = 2 }))
	end)

	it("evaluates round_number_at_least", function()
		assert.is_true(conditions.eval({ condition_name = "round_number_at_least", value = 2 }, { round_number = 3 }))
		assert.is_true(conditions.eval({ condition_name = "round_number_at_least", value = 2 }, { round_number = 2 }))
		assert.is_false(conditions.eval({ condition_name = "round_number_at_least", value = 3 }, { round_number = 2 }))
	end)

	it("capture_stone_supplemental_target passes with row and col for zero-liberty enemy", function()
		local state = { board = board.new(), test_rng_streams = { capture_stone = test_helper.rng_always_one } }
		state.board[4][5] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[5][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[5][5] = board.make_stone(config.STONE_WHITE, "stone_basic")
		state.board[5][6] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[6][5] = board.make_stone(config.STONE_BLACK, "stone_basic")
		local pass, fragment = capture_stone_supplemental_target.eval(state, config.OWNER_BLACK, nil)
		assert.is_true(pass)
		assert.are.same({ row = 5, col = 5 }, fragment)
	end)

	it("capture_stone_supplemental_target fails when enemy still has a liberty", function()
		local state = { board = board.new() }
		state.board[4][5] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[5][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[5][5] = board.make_stone(config.STONE_WHITE, "stone_basic")
		state.board[5][6] = board.make_stone(config.STONE_BLACK, "stone_basic")
		local pass, fragment = capture_stone_supplemental_target.eval(state, config.OWNER_BLACK, nil)
		assert.is_false(pass)
		assert.is_nil(fragment)
	end)

	it("capture_stone_supplemental_target excludes already-captured cells", function()
		local state = { board = board.new(), test_rng_streams = { capture_stone = test_helper.rng_always_one } }
		state.board[3][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[4][3] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[4][5] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[5][4] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[5][6] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[6][5] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[6][7] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[7][6] = board.make_stone(config.STONE_BLACK, "stone_basic")
		state.board[6][6] = board.make_stone(config.STONE_WHITE, "stone_basic")
		local pass, fragment = capture_stone_supplemental_target.eval(state, config.OWNER_BLACK, nil)
		assert.is_true(pass)
		assert.are.same({ row = 6, col = 6 }, fragment)
	end)
end)
