--- Runtime run_state implementation conforming to single_run/run_state.schema.md
--- Persists across multiple games in one run.
--- @module single_run.run_state

local rng = require("single_run.rng")
local M = {}

--- Create a new run_state.
--- @param run_id string: Unique run identifier
--- @param base_seed integer: Deterministic seed for all RNG
--- @return table: Fully initialized run_state
function M.new(run_id, base_seed)
	return {
		meta = {
			run_id = run_id,
			ruleset_version = "v1",
		},

		seed = rng.new_seed_state(base_seed),

		progression = {
			game_index = 1,
			wins = 0,
			losses = 0,
			mini_bosses_defeated = 0,
			bosses_defeated = 0,
		},

		resources = {
			money = 0,
			max_stance_slots = 2,
			rerolls = 0,
		},

		inventory = {
			stones = { instance_ids = {} },
			cards = { instance_ids = {} },
			stances = { instance_ids = {} },
		},

		instance_store = {},

		destroyed = {
			stones = {},
			cards = {},
			stances = {},
		},

		disabled = {},

		probability_modifiers = {
			by_rarity = { common = 1.0, uncommon = 1.0, rare = 1.0 },
			by_type = { stone = 1.0, card = 1.0, stance = 1.0 },
			tags = {},
		},

		history = {
			games = {},
			counters = {
				total_cards_played = 0,
				total_stones_played = 0,
				total_captures = 0,
				by_instance_use = {},
			},
		},

		pending_effects = {},
	}
end

--- Get RNG value for a key.
--- @param run_state table
--- @param key string
--- @return number: Float in [0, 1)
function M.rng_float(run_state, key)
	return rng.next_float(run_state, key)
end

--- Get RNG integer for a key.
--- @param run_state table
--- @param key string
--- @param n integer: Max value
--- @return integer: [1, n]
function M.rng_int(run_state, key, n)
	return rng.next_int(run_state, key, n)
end

--- Get an instance from the store.
--- @param run_state table
--- @param instance_id string
--- @return table|nil: ObjectInstance or nil if not found
function M.get_instance(run_state, instance_id)
	return run_state.instance_store[instance_id]
end

--- Store an instance.
--- @param run_state table
--- @param instance table: ObjectInstance with instance_id
--- @return nil
function M.store_instance(run_state, instance)
	run_state.instance_store[instance.instance_id] = instance
end

return M
