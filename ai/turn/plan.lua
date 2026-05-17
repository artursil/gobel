--- Per-turn action queue for bot MAIN → PLACE pipeline.
--- Cleared after a successful PLACE_STONE or PASS_TURN (see ``game.tick_ai``).
--- @module ai.turn.plan

local M = {}

--- @param game table
--- @return nil
function M.clear(game)
	game.ai_turn_plan = nil
end

--- @param game table
--- @return boolean
function M.has_steps(game)
	return game.ai_turn_plan ~= nil and #game.ai_turn_plan > 0
end

--- @param game table
--- @param actions table[]
--- @return nil
function M.set(game, actions)
	game.ai_turn_plan = actions
end

--- @param view table
--- @param action table
--- @return boolean
function M.action_valid_for_phase(view, action)
	local phase = view:phase()
	if phase == "MAIN_PHASE" then
		return action.type == "PLAY_CARD"
			or action.type == "SELECT_BOARD_TARGET"
			or action.type == "SELECT_STONE"
	end
	if phase == "PLACE_PHASE" then
		return action.type == "SELECT_STONE" or action.type == "PLACE_STONE" or action.type == "PASS_TURN"
	end
	return false
end

--- @param view table
--- @return table|nil
function M.pop_valid(view)
	local game = view:raw_game()
	local plan = game.ai_turn_plan
	if not plan then
		return nil
	end
	while #plan > 0 do
		local action = table.remove(plan, 1)
		if M.action_valid_for_phase(view, action) then
			return action
		end
	end
	return nil
end

return M
