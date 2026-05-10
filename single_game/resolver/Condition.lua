--- Condition schema runtime implementation conforming to single_game/resolver/Condition.schema.md
--- Unified condition evaluation for gating effects
--- @module single_game.resolver.Condition

local config = require("config")

local M = {}

--- Create a condition context from components.
--- @param run_state table
--- @param game_state table
--- @param actor string: `config.OWNER_BLACK` or `config.OWNER_WHITE`
--- @param source_instance_id string|nil
--- @param source_def_id string|nil
--- @param source_object_type string|nil: "stone" | "card" | "stance"
--- @return table: ConditionContext
function M.new_context(run_state, game_state, actor, source_instance_id, source_def_id, source_object_type)
	local opponent = (actor == config.OWNER_BLACK) and config.OWNER_WHITE or config.OWNER_BLACK
	return {
		run_state = run_state,
		game_state = game_state,

		actor = actor,
		opponent = opponent,

		source_instance_id = source_instance_id,
		source_def_id = source_def_id,
		source_object_type = source_object_type,

		action = {
			action_type = nil,
			payload = {},
		},

		trigger = {
			event_name = nil,
			payload = {},
		},

		selected_targets = {
			row = nil,
			col = nil,
			instance_id = nil,
		},

		rng = {
			next_float = function(key)
				return run_state and require("single_run.run_state").rng_float(run_state, key) or 0.5
			end,
			next_int = function(key, n)
				return run_state and require("single_run.run_state").rng_int(run_state, key, n) or 1
			end,
		},
	}
end

--- Evaluate a single condition def.
--- @param condition_def table: {condition_name, value, params}
--- @param context table: ConditionContext
--- @return boolean: true if condition passes
function M.eval_single(condition_def, context)
	if not condition_def or not condition_def.condition_name then
		return true
	end

	local condition_name = condition_def.condition_name
	local value = condition_def.value
	local params = condition_def.params or {}

	if condition_name == "always" then
		return true
	elseif condition_name == "never" then
		return false
	elseif condition_name == "random" then
		local probability = value or 0.5
		return context.rng.next_float("condition.random") < probability
	elseif condition_name == "prisoners_captured_at_least" then
		if not context.game_state then
			return false
		end
		local player = context.game_state.players[context.actor]
		return player and player.counters.prisoners_captured >= value
	elseif condition_name == "stones_captured_at_least" then
		if not context.game_state then
			return false
		end
		local player = context.game_state.players[context.actor]
		return player and player.counters.stones_captured >= value
	elseif condition_name == "cards_played_at_least" then
		if not context.game_state then
			return false
		end
		local player = context.game_state.players[context.actor]
		return player and player.counters.cards_played >= value
	elseif condition_name == "stones_played_at_least" then
		if not context.game_state then
			return false
		end
		local player = context.game_state.players[context.actor]
		return player and player.counters.stones_played >= value
	elseif condition_name == "turn_number_at_least" then
		if not context.game_state then
			return false
		end
		return context.game_state.meta.turn_number >= value
	elseif condition_name == "turn_number_exactly" then
		if not context.game_state then
			return false
		end
		return context.game_state.meta.turn_number == value
	else
		-- Unknown condition: fail-safe to true (doesn't block effect)
		return true
	end
end

--- Evaluate all conditions (all must pass).
--- @param conditions table|nil: Array of condition defs
--- @param context table: ConditionContext
--- @return boolean: true if all pass (or none present)
function M.eval_all(conditions, context)
	if not conditions or #conditions == 0 then
		return true
	end
	for i = 1, #conditions do
		if not M.eval_single(conditions[i], context) then
			return false
		end
	end
	return true
end

return M
