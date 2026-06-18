require("spec.test_helper")

local test_helper = require("spec.test_helper")
local board = require("board")
local config = require("config")
local conditions = require("objects.effects_conditions.conditions")
local capture_stone_supplemental_target = require("objects.effects_conditions.conditions.capture_stone_supplemental_target")

describe("T-101 conditions system", function()
	it("evaluates always condition as true", function()
		assert.is_true(conditions.eval({ condition_name = "always" }, {}))
	end)

	it("evaluates never condition as false", function()
		assert.is_false(conditions.eval({ condition_name = "never" }, {}))
	end)

	it("evaluates random condition with probability 1.0", function()
		local def = { condition_name = "random", probability = 1.0 }
		assert.is_true(conditions.eval(def, {}))
	end)

	it("evaluates random condition with probability 0.0", function()
		local def = { condition_name = "random", probability = 0.0 }
		assert.is_false(conditions.eval(def, {}))
	end)

	it("evaluates random condition with invalid probability as false", function()
		local def = { condition_name = "random", probability = nil }
		assert.is_false(conditions.eval(def, {}))
	end)

	it("fractional random without rng is false (replay-safe fallback)", function()
		assert.is_false(conditions.eval({ condition_name = "random", probability = 0.37 }, {}))
		assert.is_false(conditions.eval({ condition_name = "random", probability = 0.37 }, nil))
	end)

	it("fractional random uses state.rng deterministically", function()
		local def = { condition_name = "random", probability = 0.37 }
		local s1 = { rng = { seed = 94211 } }
		local s2 = { rng = { seed = 94211 } }
		local pass1 = conditions.eval(def, s1)
		local pass2 = conditions.eval(def, s2)
		assert.are.equal(pass1, pass2)
	end)

	it("evaluates empty conditions array as true (pass-through)", function()
		assert.is_true(conditions.eval_all({}, {}))
	end)

	it("evaluates nil conditions as true (pass-through)", function()
		assert.is_true(conditions.eval_all(nil, {}))
	end)

	it("evaluates single always condition as true", function()
		local cond_array = { { condition_name = "always" } }
		assert.is_true(conditions.eval_all(cond_array, {}))
	end)

	it("evaluates single never condition as false", function()
		local cond_array = { { condition_name = "never" } }
		assert.is_false(conditions.eval_all(cond_array, {}))
	end)

	it("short-circuits on first false condition", function()
		local cond_array = {
			{ condition_name = "always" },
			{ condition_name = "never" },
			{ condition_name = "always" },
		}
		assert.is_false(conditions.eval_all(cond_array, {}))
	end)

	it("evaluates all conditions as true when all pass", function()
		local cond_array = {
			{ condition_name = "always" },
			{ condition_name = "always" },
		}
		assert.is_true(conditions.eval_all(cond_array, {}))
	end)

	it("returns true for unknown condition name (fail-safe)", function()
		local cond_array = { { condition_name = "unknown_condition" } }
		assert.is_true(conditions.eval_all(cond_array, {}))
	end)

	it("evaluates single condition by name", function()
		assert.is_true(conditions.eval("always", {}))
		assert.is_false(conditions.eval("never", {}))
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
