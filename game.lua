--- Match flow: turns, passes, scoring, bot games, two-player games, and stone pipelines.

local ai = require("ai")
local board = require("board")
local config = require("config")
local content = require("content")
local deck = require("deck")
local energy = require("energy")
local match_state = require("match_state")
local poses = require("poses")
local pouch = require("pouch")
local rules = require("rules")
local scoring = require("scoring")

local M = {}

local function is_black_turn(color)
	return color == "black"
end

local function is_white_turn(color)
	return color == "white"
end

local function opponent_color(color)
	if is_black_turn(color) then
		return "white"
	end
	return "black"
end

local function color_to_stone(color)
	if is_black_turn(color) then
		return config.STONE_BLACK
	end
	return config.STONE_WHITE
end

--- Whether the active player is controlled by this device (both colors in PvP, only Black vs bot).
--- @param g table
--- @return boolean
function M.is_human_turn(g)
	if g.over then
		return false
	end
	if not g.versus_bot then
		return true
	end
	return is_black_turn(g.to_play)
end

--- Builds a fresh game for local two-player or Black vs random White.
--- @param match_kind string "pvp" or "pvc"
--- @return table
function M.new(match_kind)
	local g = match_state.new_match(match_kind)
	local status
	if g.versus_bot then
		status = "Your turn (Black). White is a random bot."
	else
		status = "Black to play — shared mouse, two players."
	end
	g.status = status
	M.start_turn(g, g.to_play)
	return g
end

function M._apply_effect(player_state, effect)
	if effect.type == "ADD_POINTS" then
		player_state.score.points_bonus = player_state.score.points_bonus + effect.value
	elseif effect.type == "ADD_MULT" then
		player_state.score.mult_bonus = player_state.score.mult_bonus + effect.value
	end
end

function M.start_turn(g, color)
	local player_state = match_state.player_for_color(g, color)
	energy.refresh(player_state.resources)
	if not player_state.stones.active_stone then
		player_state.stones.active_stone = pouch.draw(player_state.stones.pouch)
	end
	deck.draw_to_hand_target(player_state.cards, function(max_value)
		return match_state.rng_next_int(g, max_value)
	end)
	poses.dispatch_trigger(player_state, "TURN_START", function(_, pose_def)
		M._apply_effect(player_state, pose_def.effect)
	end)
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
	local color = g.to_play
	local player_state = match_state.player_for_color(g, color)
	local stone_id = player_state.stones.active_stone
	if not stone_id then
		g.status = "No active stone. Pass or end turn."
		return false
	end
	local stone_def = content.get_stone(stone_id)
	if not stone_def then
		g.status = "Internal error: unknown stone."
		return false
	end
	local ok, new_board, new_ko, caps = rules.try_play(g.board, row, col, color_to_stone(color), g.ko_ban, stone_id)
	if not ok then
		g.status = "Illegal move."
		return false
	end
	g.board = new_board
	g.ko_ban = new_ko
	player_state.prisoners = player_state.prisoners + caps
	player_state.stones.active_stone = nil
	M._apply_effect(player_state, stone_def.placement_effect)
	g.consecutive_passes = 0
	local next_c = opponent_color(color)
	g.to_play = next_c
	M.start_turn(g, next_c)
	if g.versus_bot and is_white_turn(next_c) then
		g.status = "White is thinking…"
		g.ai_delay = 0.35
	elseif g.versus_bot then
		g.status = "Your turn (Black)."
	else
		if is_black_turn(next_c) then
			g.status = "Black to play."
		else
			g.status = "White to play."
		end
	end
	return true
end

--- Records a pass for the current human-controlled side.
--- @param g table
function M.player_pass(g)
	if not M.is_human_turn(g) then
		return
	end
	g.consecutive_passes = g.consecutive_passes + 1
	if g.consecutive_passes >= 2 then
		M.finish(g)
		return
	end
	local was = g.to_play
	g.to_play = opponent_color(was)
	M.start_turn(g, g.to_play)
	if g.versus_bot and is_white_turn(g.to_play) then
		g.status = "You passed. White to play."
		g.ai_delay = 0.35
	elseif g.versus_bot then
		g.status = "White passed. Your turn (Black)."
	else
		if is_black_turn(g.to_play) then
			g.status = "White passed. Black to play."
		else
			g.status = "Black passed. White to play."
		end
	end
end

--- Runs the random AI when it is White's turn in bot mode.
--- @param g table
--- @param dt number
function M.tick_ai(g, dt)
	if g.over or not g.versus_bot or not is_white_turn(g.to_play) then
		return
	end
	if g.ai_delay > 0 then
		g.ai_delay = g.ai_delay - dt
		return
	end
	local r, c = ai.random_move(g)
	if not r then
		g.consecutive_passes = g.consecutive_passes + 1
		if g.consecutive_passes >= 2 then
			M.finish(g)
			return
		end
		g.to_play = "black"
		M.start_turn(g, "black")
		g.status = "White passed. Your turn (Black)."
		return
	end
	local ai_state = match_state.player_for_color(g, config.AI_COLOR)
	local stone_id = ai_state.stones.active_stone
	if not stone_id then
		g.status = "White passed. Your turn (Black)."
		g.consecutive_passes = g.consecutive_passes + 1
		if g.consecutive_passes >= 2 then
			M.finish(g)
			return
		end
		g.to_play = "black"
		M.start_turn(g, "black")
		return
	end
	local stone_def = content.get_stone(stone_id)
	if not stone_def then
		g.status = "Internal error: AI stone missing."
		return
	end
	local kind = stone_id
	local ok, new_board, new_ko, caps = rules.try_play(g.board, r, c, config.AI_COLOR, g.ko_ban, kind)
	if not ok then
		g.status = "Internal error: AI illegal move."
		return
	end
	g.board = new_board
	g.ko_ban = new_ko
	ai_state.prisoners = ai_state.prisoners + caps
	ai_state.stones.active_stone = nil
	M._apply_effect(ai_state, stone_def.placement_effect)
	g.consecutive_passes = 0
	g.to_play = "black"
	M.start_turn(g, "black")
	g.status = "Your turn (Black)."
end

--- Marks the game finished and sets the winner from live scoring totals.
--- @param g table
function M.finish(g)
	g.over = true
	g.ended = true
	g.to_play = "none"
	local b = g.board
	local black_state = g.players.black
	local white_state = g.players.white
	local points_b = scoring.liberty_points(b, config.STONE_BLACK) + black_state.score.points_bonus
	local mult_b = scoring.overall_mult(b, config.STONE_BLACK) + black_state.score.mult_bonus
	local points_w = scoring.liberty_points(b, config.STONE_WHITE) + white_state.score.points_bonus
	local mult_w = scoring.overall_mult(b, config.STONE_WHITE) + white_state.score.mult_bonus
	local score_b = points_b * mult_b
	local score_w = points_w * mult_w
	local winner
	if score_b > score_w then
		winner = "Black"
	elseif score_w > score_b then
		winner = "White"
	else
		winner = "Draw"
	end
	g.status = string.format(
		"Game over — Black: %d  White: %d (%s). R same mode  M menu.",
		score_b,
		score_w,
		winner
	)
end

return M
