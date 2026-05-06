require("spec.test_helper")

local run_state = require("single_run.run_state")
local rng = require("single_run.rng")

describe("T-200 per-key RNG determinism", function()
	it("produces same float for same (seed, key, calls)", function()
		local rs1 = run_state.new("run1", 12345)
		local rs2 = run_state.new("run2", 12345)

		local f1 = rng.next_float(rs1, "test.key")
		local f2 = rng.next_float(rs2, "test.key")

		assert.are.equal(f1, f2)
	end)

	it("produces different float for different seed", function()
		local rs1 = run_state.new("run1", 12345)
		local rs2 = run_state.new("run2", 54321)

		local f1 = rng.next_float(rs1, "test.key")
		local f2 = rng.next_float(rs2, "test.key")

		assert.are_not_equal(f1, f2)
	end)

	it("produces different float for different key", function()
		local rs = run_state.new("run1", 12345)

		local f1 = rng.next_float(rs, "key1")
		rs.seed.streams["key1"].calls = 0
		local f2 = rng.next_float(rs, "key2")
		rs.seed.streams["key2"].calls = 0

		assert.are_not_equal(f1, f2)
	end)

	it("increments calls counter on consume", function()
		local rs = run_state.new("run1", 12345)
		
		rng.next_float(rs, "test")
		assert.are.equal(1, rs.seed.streams["test"].calls)

		rng.next_float(rs, "test")
		assert.are.equal(2, rs.seed.streams["test"].calls)
	end)

	it("produces different sequence for different call counts", function()
		local rs1 = run_state.new("run1", 12345)
		local rs2 = run_state.new("run2", 12345)

		rng.next_float(rs1, "test")
		local f1 = rng.next_float(rs1, "test")

		local f2 = rng.next_float(rs2, "test")

		assert.are_not_equal(f1, f2)
	end)

	it("converts float to int in [1, n]", function()
		local rs = run_state.new("run1", 12345)

		for _ = 1, 100 do
			local val = rng.next_int(rs, "test", 6)
			assert.is_true(val >= 1 and val <= 6)
		end
	end)

	it("produces deterministic int sequence", function()
		local rs1 = run_state.new("run1", 12345)
		local rs2 = run_state.new("run2", 12345)

		for _ = 1, 10 do
			local i1 = rng.next_int(rs1, "test", 10)
			local i2 = rng.next_int(rs2, "test", 10)
			assert.are.equal(i1, i2)
		end
	end)

	it("different keys produce different sequences", function()
		local rs1 = run_state.new("run1", 12345)
		local rs2 = run_state.new("run2", 12345)

		local f1_key1 = rng.next_float(rs1, "key1")
		local f2_key2 = rng.next_float(rs2, "key2")

		assert.are_not_equal(f1_key1, f2_key2)
	end)
end)
