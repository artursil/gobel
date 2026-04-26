--- Match flow: turns, passes, scoring, bot games, two-player games, and stone pipelines.

local ai = require("ai")
local match_state = require("match_state")
local resolver = require("resolver")

local M = {}

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
--- @return table
function M.new(match_kind)
	local g = match_state.new_match(match_kind)
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
	return g
end

local function set_status_from_result(g, result, fallback)
	if result.ok then
		local recent = g.messages.recent
		g.status = recent[#recent] or fallback
		return true
	end
	g.status = result.error
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

--- Runs the random AI when it is White's turn in bot mode.
--- @param g table
--- @param dt number
function M.tick_ai(g, dt)
	if g.over or g.ended or not g.versus_bot or g.to_play ~= "white" then
		return
	end
	if g.ai_delay > 0 then
		g.ai_delay = g.ai_delay - dt
		return
	end
	local r, c = ai.random_move(g)
	if not r then
		if g.phase == "MAIN_PHASE" then
			local move_to_place = resolver.finish_main_phase(g, g.to_play)
			if not move_to_place.ok then
				g.status = move_to_place.error
				return
			end
		end
		local pass_result = resolver.submit_action(g, {
			actor = "white",
			type = "PASS_TURN",
			payload = {},
		})
		if not pass_result.ok then
			g.status = pass_result.error
			return
		end
		g.status = "White passed. Your turn (Black)."
		return
	end
	if g.phase == "MAIN_PHASE" then
		local move_to_place = resolver.finish_main_phase(g, g.to_play)
		if not move_to_place.ok then
			g.status = move_to_place.error
			return
		end
	end
	local result = resolver.submit_action(g, {
		actor = "white",
		type = "PLACE_STONE",
		payload = { row = r, col = c },
	})
	if not result.ok then
		g.status = result.error
		return
	end
	g.status = "Your turn (Black)."
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

function M.select_stone(g, stone_id)
	if not M.is_human_turn(g) then
		return false
	end
	local result = resolver.submit_action(g, {
		actor = g.to_play,
		type = "SELECT_STONE",
		payload = { stone_id = stone_id },
	})
	return set_status_from_result(g, result, "Stone selected.")
end

return M
