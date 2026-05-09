--- Unified condition evaluation registry.
--- All conditions evaluate through this dispatcher.
--- Conditions can gate effect application or be evaluated in action context.
--- @module objects.conditions

local M = {}
local config = require("config")
local board = require("board")
local queries = require("single_game.resolver.state_queries")

--- Always true condition.
--- @param condition_def table|nil
--- @param state table|nil
--- @return boolean
function M.always(condition_def, state)
	return true
end

--- Always false condition.
--- @param condition_def table|nil
--- @param state table|nil
--- @return boolean
function M.never(condition_def, state)
	return false
end

--- Random chance using condition_def.probability or condition_def.value.
--- For probabilities strictly between 0 and 1, ``state.rng`` (``match_state`` shape) must be present; otherwise this returns ``false`` so tests/replays cannot drift ``math.random``. Endpoints ``<= 0`` and ``>= 1`` do not consume RNG.
--- @param condition_def table|nil
--- @param state table|nil
--- @return boolean
function M.random(condition_def, state)
	local probability = condition_def and (condition_def.probability or condition_def.value) or nil
	if probability == nil then
		return false
	end
	if probability <= 0 then
		return false
	end
	if probability >= 1 then
		return true
	end
	if not state or not state.rng then
		return false
	end
	local match_state = require("match_state")
	local roll = match_state.rng_next_int(state, 10000)
	return roll <= math.floor(probability * 10000)
end

--- Stone tag just added condition.
--- Checks if a stone with a specific tag was just placed on the board.
--- @param condition_def table: {condition_name, tag}
--- @param state table
--- @return boolean
function M.stone_tag_just_added(condition_def, state)
	if not condition_def or not condition_def.tag then
		return false
	end
	local last_stone = queries.last_placed_stone(state)
	if not last_stone then
		return false
	end

	local placed_stone_tags = last_stone.tags or {}
	for _, tag in ipairs(placed_stone_tags) do
		if tag == condition_def.tag then
			return true
		end
	end
	return false
end

--- Temporary stance expired condition.
--- Checks if a temporary stance has expired (remaining_rounds <= 0).
--- @param condition_def table: {condition_name}
--- @param state table
--- @return boolean
function M.temporary_stance_expired(condition_def, state)
	local instance = queries.source_stance_instance(state)
	if not instance then
		return false
	end
	local ObjectInstance = require("single_game.resolver.ObjectInstance")
	return ObjectInstance.is_expired(instance)
end

--- Temporary stance active condition.
--- Checks if a temporary stance is still active (remaining_rounds > 0).
--- @param condition_def table: {condition_name}
--- @param state table
--- @return boolean
function M.temporary_stance_active(condition_def, state)
	local instance = queries.source_stance_instance(state)
	if not instance then
		return true
	end
	local ObjectInstance = require("single_game.resolver.ObjectInstance")
	return not ObjectInstance.is_expired(instance)
end

--- Stance owner is current turn owner condition.
--- @param condition_def table: {condition_name}
--- @param state table
--- @return boolean
function M.stance_owner_is_current_turn(condition_def, state)
	return queries.source_owner(state) ~= nil
		and queries.current_turn_owner(state) ~= nil
		and queries.source_owner(state) == queries.current_turn_owner(state)
end

--- Selected board target exists in effect context.
--- @param condition_def table
--- @param state table
--- @return boolean
function M.selected_target_exists(condition_def, state)
	local target = queries.selected_target(state)
	return target ~= nil and target.row ~= nil and target.col ~= nil
end

--- Selected target must be an enemy stone relative to effect owner.
--- @param condition_def table
--- @param state table
--- @return boolean
function M.selected_target_is_enemy_stone(condition_def, state)
	if not M.selected_target_exists(condition_def, state) then
		return false
	end
	local owner = queries.effect_owner(state)
	if not state or not owner then
		return false
	end
	local target = queries.selected_target(state)
	local row = target.row
	local col = target.col
	local cell = state.board and state.board[row] and state.board[row][col]
	if board.is_empty(cell) then
		return false
	end
	local owner_color = owner == "A" and config.STONE_BLACK or config.STONE_WHITE
	return cell.color ~= owner_color
end

--- Selected target must be a friendly stone relative to effect owner.
--- @param condition_def table
--- @param state table
--- @return boolean
function M.selected_target_is_friendly_stone(condition_def, state)
	if not M.selected_target_exists(condition_def, state) then
		return false
	end
	local owner = queries.effect_owner(state)
	if not state or not owner then
		return false
	end
	local target = queries.selected_target(state)
	local row = target.row
	local col = target.col
	local cell = state.board and state.board[row] and state.board[row][col]
	if board.is_empty(cell) then
		return false
	end
	local owner_color = owner == "A" and config.STONE_BLACK or config.STONE_WHITE
	return cell.color == owner_color
end

--- Evaluate a single condition.
--- Dispatch by condition name; return true if unknown (fail-safe).
--- @param condition_def table: {condition_name, ...params...}
--- @param state table
--- @return boolean
local function eval_single(condition_def, state)
	if not condition_def then
		return true
	end
	if not condition_def.condition_name then
		return true
	end
	local evaluator = M[condition_def.condition_name]
	if not evaluator then
		return true
	end
	return evaluator(condition_def, state)
end

--- Evaluate an array of conditions (all must pass).
--- Returns true if conditions array is nil or empty (no conditions = always pass).
--- Returns false if any condition fails (fail-fast on first false).
--- @param conditions table|nil: array of {condition_name, ...}
--- @param state table: evaluation state
--- @return boolean
function M.eval_all(conditions, state)
	if not conditions or #conditions == 0 then
		return true
	end
	for i = 1, #conditions do
		if not eval_single(conditions[i], state) then
			return false
		end
	end
	return true
end

--- Evaluate a single condition by name (convenience function).
--- @param condition_name string
--- @param state table
--- @return boolean
function M.eval(condition_name, state)
	local evaluator = M[condition_name]
	if not evaluator then
		return true
	end
	return evaluator(nil, state)
end

return M
