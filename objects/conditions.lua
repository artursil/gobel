--- Unified condition evaluation registry.
--- All conditions evaluate through this dispatcher.
--- Conditions can gate effect application or be evaluated in action context.
--- @module objects.conditions

local M = {}
local config = require("config")
local board = require("board")

--- Always true condition.
--- @param context table
--- @return boolean
function M.always(context)
	return true
end

--- Always false condition.
--- @param context table
--- @return boolean
function M.never(context)
	return false
end

--- Random chance condition (requires context.rng and context.probability).
--- @param context table: {rng?, probability?}
--- @return boolean
function M.random(context)
	if not context or not context.probability then
		return false
	end
	if context.probability <= 0 then
		return false
	end
	if context.probability >= 1 then
		return true
	end
	if context.rng then
		return context.rng:random() < context.probability
	end
	return math.random() < context.probability
end

--- Stone tag just added condition.
--- Checks if a stone with a specific tag was just placed on the board.
--- @param condition_def table: {condition_name, tag}
--- @param context table: {last_placed_stone?, ...}
--- @return boolean
function M.stone_tag_just_added(condition_def, context)
	if not condition_def or not condition_def.tag then
		return false
	end
	if not context or not context.last_placed_stone then
		return false
	end

	local placed_stone_tags = context.last_placed_stone.tags or {}
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
--- @param context table: {instance?}
--- @return boolean
function M.temporary_stance_expired(condition_def, context)
	if not context or not context.instance then
		return false
	end
	local ObjectInstance = require("single_game.resolver.ObjectInstance")
	return ObjectInstance.is_expired(context.instance)
end

--- Temporary stance active condition.
--- Checks if a temporary stance is still active (remaining_rounds > 0).
--- @param condition_def table: {condition_name}
--- @param context table: {instance?}
--- @return boolean
function M.temporary_stance_active(condition_def, context)
	if not context or not context.instance then
		return true
	end
	local ObjectInstance = require("single_game.resolver.ObjectInstance")
	return not ObjectInstance.is_expired(context.instance)
end

--- Stance owner is current turn owner condition.
--- @param condition_def table: {condition_name}
--- @param context table: {stance_owner?, current_turn_owner?}
--- @return boolean
function M.stance_owner_is_current_turn(condition_def, context)
	if not context then
		return false
	end
	return context.stance_owner ~= nil and context.current_turn_owner ~= nil and context.stance_owner == context.current_turn_owner
end

--- Selected board target exists in effect context.
--- @param condition_def table
--- @param context table
--- @return boolean
function M.selected_target_exists(condition_def, context)
	return context
		and context.selected_target
		and context.selected_target.row ~= nil
		and context.selected_target.col ~= nil
end

--- Selected target must be an enemy stone relative to effect owner.
--- @param condition_def table
--- @param context table
--- @return boolean
function M.selected_target_is_enemy_stone(condition_def, context)
	if not M.selected_target_exists(condition_def, context) then
		return false
	end
	local state = context.state
	local owner = context.effect_owner
	if not state or not owner then
		return false
	end
	local row = context.selected_target.row
	local col = context.selected_target.col
	local cell = state.board and state.board[row] and state.board[row][col]
	if board.is_empty(cell) then
		return false
	end
	local owner_color = owner == "A" and config.STONE_BLACK or config.STONE_WHITE
	return cell.color ~= owner_color
end

--- Selected target must be a friendly stone relative to effect owner.
--- @param condition_def table
--- @param context table
--- @return boolean
function M.selected_target_is_friendly_stone(condition_def, context)
	if not M.selected_target_exists(condition_def, context) then
		return false
	end
	local state = context.state
	local owner = context.effect_owner
	if not state or not owner then
		return false
	end
	local row = context.selected_target.row
	local col = context.selected_target.col
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
--- @param context table: {rng?, probability?, state?, owner?, ...}
--- @return boolean
local function eval_single(condition_def, context)
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
	return evaluator(condition_def, context)
end

--- Evaluate an array of conditions (all must pass).
--- Returns true if conditions array is nil or empty (no conditions = always pass).
--- Returns false if any condition fails (fail-fast on first false).
--- @param conditions table|nil: array of {condition_name, ...}
--- @param context table: evaluation context
--- @return boolean
function M.eval_all(conditions, context)
	if not conditions or #conditions == 0 then
		return true
	end
	for i = 1, #conditions do
		if not eval_single(conditions[i], context) then
			return false
		end
	end
	return true
end

--- Evaluate a single condition by name (convenience function).
--- @param condition_name string
--- @param context table
--- @return boolean
function M.eval(condition_name, context)
	local evaluator = M[condition_name]
	if not evaluator then
		return true
	end
	return evaluator(context)
end

return M
