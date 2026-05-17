--- Match flow: turns, passes, scoring, bot games, two-player games, and stone pipelines.

local ai_controller = require("ai.controller")
local mcts_config = require("ai.mcts_config")
local match_state = require("match_state")
local messages = require("messages")
local resolver = require("resolver")
local game_type_resolver = require("game_types.resolver")

local M = {}
local RUN_PERSISTENCE = {
	counters = {},
}

--- Whether the active player is controlled by this device (both colors in PvP, only Black vs bot).
--- @param g table
--- @return boolean
function M.is_human_turn(g)
	if g.over or g.ended then
		return false
	end
	if not g.versus_bot then
		return true
	end
	return g.to_play == "black"
end

--- Builds a fresh game for local two-player or Black vs random White.
--- @param match_kind string "pvp" or "pvc"
--- @param game_type_id string|nil
--- @param territory_mode string|nil
--- @return table
function M.new(match_kind, game_type_id, territory_mode)
	game_type_id = game_type_id or "standard"
	local g = match_state.new_match(match_kind, territory_mode)
	g.run_state = RUN_PERSISTENCE
	game_type_resolver.apply_game_type(g, game_type_id)
	g.to_play = "black"
	local started = resolver.begin_turn(g, g.to_play)
	if not started.ok then
		g.status = started.error
		return g
	end
	local recent = g.messages.recent
	local latest = recent[#recent]
	if latest then
		g.status = latest
	end
	g.game_type_id = game_type_id
	if g.versus_bot then
		g.ai_strategy = "heuristic"
		g.ai_difficulty = "normal"
		g.ai_mcts = mcts_config.for_difficulty("normal")
		g.ai_planner_enabled = true
		g.ai_planner_max_scripts = 12
	end
	return g
end

local function set_status_from_result(g, result, fallback)
	if result.ok then
		local recent = g.messages.recent
		g.status = recent[#recent] or fallback
		return true
	end
	g.status = result.error
	if result.error and (string.sub(result.error, 1, 12) == "Illegal move") then
		messages.push(g.messages, result.error)
	end
	return false
end

--- Applies a stone play for the current human-controlled side when the move is legal.
--- @param g table
--- @param row integer
--- @param col integer
--- @return boolean
function M.player_move(g, row, col)
	if not M.is_human_turn(g) then
		return false
	end
	if g.phase == "MAIN_PHASE" then
		local move_to_place = resolver.finish_main_phase(g, g.to_play)
		if not set_status_from_result(g, move_to_place, "Choose placement.") then
			return false
		end
	end
	local result = resolver.submit_action(g, {
		actor = g.to_play,
		type = "PLACE_STONE",
		payload = { row = row, col = col },
	})
	if not set_status_from_result(g, result, "Move resolved.") then
		return false
	end
	if g.versus_bot and g.to_play == "white" and not g.ended then
		g.status = "White is thinking…"
		g.ai_delay = 0.35
	elseif g.versus_bot and not g.ended then
		g.status = "Your turn (Black)."
	end
	return true
end

--- Records a pass for the current human-controlled side.
--- @param g table
function M.player_pass(g)
	if not M.is_human_turn(g) then
		return
	end
	if g.phase == "MAIN_PHASE" then
		local move_to_place = resolver.finish_main_phase(g, g.to_play)
		if not set_status_from_result(g, move_to_place, "Choose placement.") then
			return
		end
	end
	local result = resolver.submit_action(g, {
		actor = g.to_play,
		type = "PASS_TURN",
		payload = {},
	})
	if not set_status_from_result(g, result, "Pass resolved.") then
		return
	end
	if g.versus_bot and g.to_play == "white" and not g.ended then
		g.status = "You passed. White to play."
		g.ai_delay = 0.35
	elseif g.versus_bot and not g.ended then
		g.status = "White passed. Your turn (Black)."
	end
end

--- Runs the bot when it is the configured AI side's turn (one resolver action per tick).
--- @param g table
--- @param dt number
function M.tick_ai(g, dt)
	if g.over or g.ended or not ai_controller.is_bot_turn(g) then
		return
	end
	if g.ai_delay > 0 then
		g.ai_delay = g.ai_delay - dt
		return
	end
	local action, signal = ai_controller.decide(g)
	if signal == "finish_main" then
		local move_to_place = resolver.finish_main_phase(g, g.to_play)
		if not move_to_place.ok then
			g.status = move_to_place.error
			return
		end
		g.ai_delay = 0.15
		return
	end
	if not action then
		return
	end
	local result = resolver.submit_action(g, action)
	if not result.ok then
		g.status = result.error
		return
	end
	if action.type == "PLACE_STONE" or action.type == "PASS_TURN" then
		local turn_plan = require("ai.turn.plan")
		turn_plan.clear(g)
	end
	local bot = ai_controller.bot_actor()
	if action.type == "PASS_TURN" then
		if bot == "white" then
			g.status = "White passed. Your turn (Black)."
		else
			g.status = "Black passed. Your turn (White)."
		end
	elseif g.to_play == bot and not g.ended then
		if bot == "white" then
			g.status = "White is thinking…"
		else
			g.status = "Black is thinking…"
		end
		g.ai_delay = 0.35
	elseif bot == "white" then
		g.status = "Your turn (Black)."
	else
		g.status = "Your turn (White)."
	end
end

function M.play_card(g, hand_index)
	if not M.is_human_turn(g) then
		return false
	end
	local result = resolver.submit_action(g, {
		actor = g.to_play,
		type = "PLAY_CARD",
		payload = { hand_index = hand_index },
	})
	return set_status_from_result(g, result, "Card resolved.")
end

function M.select_board_target(g, row, col)
	if not M.is_human_turn(g) then
		return false
	end
	local result = resolver.submit_action(g, {
		actor = g.to_play,
		type = "SELECT_BOARD_TARGET",
		payload = { row = row, col = col },
	})
	return set_status_from_result(g, result, "Board target selected.")
end

function M.select_stone(g, stone_id, stone_index)
	if not M.is_human_turn(g) then
		return false
	end
	local result = resolver.submit_action(g, {
		actor = g.to_play,
		type = "SELECT_STONE",
		payload = { stone_id = stone_id, stone_index = stone_index },
	})
	return set_status_from_result(g, result, "Stone selected.")
end

return M
