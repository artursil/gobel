--- Per-key deterministic RNG manager.
--- Output: function(base_seed, key, calls) -> value
--- No mutable per-stream state blob; only counter increments.
--- @module single_run.rng

local M = {}

--- LCG parameters (from match_state.lua)
local MODULUS = 2147483647
local MULTIPLIER = 48271

--- Generate a pseudo-random number from seed and call count.
--- Deterministic: same (seed, key, calls) always produces same value.
--- @param base_seed integer: Run base seed
--- @param key string: Stream key (e.g., "draw.cards.player")
--- @param calls integer: Number of calls on this stream
--- @return number: Float in [0, 1)
local function lcg_value(base_seed, key, calls)
	local key_hash = 0
	for i = 1, #key do
		key_hash = (key_hash * 31 + string.byte(key, i)) % MODULUS
	end
	local combined = (base_seed + key_hash + calls) % MODULUS
	local state = (combined * MULTIPLIER) % MODULUS
	return state / MODULUS
end

--- Consume next float from RNG stream.
--- Reads calls, computes value, increments calls.
--- @param run_state table: Must have seed.base_seed and seed.streams[key]
--- @param key string: Stream key
--- @return number: Float in [0, 1)
function M.next_float(run_state, key)
	if not run_state.seed.streams[key] then
		run_state.seed.streams[key] = { calls = 0 }
	end
	local stream = run_state.seed.streams[key]
	local calls = stream.calls
	local value = lcg_value(run_state.seed.base_seed, key, calls)
	stream.calls = calls + 1
	return value
end

--- Consume next integer from RNG stream.
--- Range: [1, n]
--- @param run_state table: Must have seed.base_seed and seed.streams[key]
--- @param key string: Stream key
--- @param n integer: Max value (inclusive)
--- @return integer: Integer in [1, n]
function M.next_int(run_state, key, n)
	if n < 1 then
		return 1
	end
	local float_val = M.next_float(run_state, key)
	return math.floor(float_val * n) + 1
end

--- Initialize RNG state for a run.
--- @param base_seed integer
--- @return table: {base_seed, streams = {}}
function M.new_seed_state(base_seed)
	return {
		base_seed = base_seed,
		streams = {},
	}
end

return M
