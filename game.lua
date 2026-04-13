--- Match flow: turns, passes, scoring, bot games, and two-player same-device games.

local ai = require("ai")
local board = require("board")
local config = require("config")
local rules = require("rules")

local M = {}

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
	return g.to_play == config.STONE_BLACK
end

--- Builds a fresh game for local two-player or Black vs random White.
--- @param match_kind string "pvp" or "pvc"
--- @return table
function M.new(match_kind)
	local versus_bot = match_kind == "pvc"
	local status
	if versus_bot then
		status = "Your turn (Black). White is a random bot."
	else
		status = "Black to play — shared mouse, two players."
	end
	return {
		board = board.new(),
		to_play = config.STONE_BLACK,
		ko_ban = nil,
		prisoners = { [config.STONE_BLACK] = 0, [config.STONE_WHITE] = 0 },
		consecutive_passes = 0,
		over = false,
		status = status,
		ai_delay = 0,
		versus_bot = versus_bot,
		match_kind = match_kind,
	}
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
	local ok, new_board, new_ko, caps = rules.try_play(g.board, row, col, color, g.ko_ban)
	if not ok then
		g.status = "Illegal move."
		return false
	end
	g.board = new_board
	g.ko_ban = new_ko
	g.prisoners[color] = g.prisoners[color] + caps
	g.consecutive_passes = 0
	local next_c = board.opponent_stone(color)
	g.to_play = next_c
	if g.versus_bot and next_c == config.AI_COLOR then
		g.status = "White is thinking…"
		g.ai_delay = 0.35
	elseif g.versus_bot then
		g.status = "Your turn (Black)."
	else
		if next_c == config.STONE_BLACK then
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
	g.to_play = board.opponent_stone(was)
	if g.versus_bot and g.to_play == config.AI_COLOR then
		g.status = "You passed. White to play."
		g.ai_delay = 0.35
	elseif g.versus_bot then
		g.status = "White passed. Your turn (Black)."
	else
		if g.to_play == config.STONE_BLACK then
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
	if g.over or not g.versus_bot or g.to_play ~= config.AI_COLOR then
		return
	end
	if g.ai_delay > 0 then
		g.ai_delay = g.ai_delay - dt
		return
	end
	local r, c = ai.random_move(g.board, g.ko_ban)
	if not r then
		g.consecutive_passes = g.consecutive_passes + 1
		if g.consecutive_passes >= 2 then
			M.finish(g)
			return
		end
		g.to_play = config.STONE_BLACK
		g.status = "White passed. Your turn (Black)."
		return
	end
	local ok, new_board, new_ko, caps = rules.try_play(g.board, r, c, config.AI_COLOR, g.ko_ban)
	if not ok then
		g.status = "Internal error: AI illegal move."
		return
	end
	g.board = new_board
	g.ko_ban = new_ko
	g.prisoners[config.AI_COLOR] = g.prisoners[config.AI_COLOR] + caps
	g.consecutive_passes = 0
	g.to_play = config.STONE_BLACK
	g.status = "Your turn (Black)."
end

--- Counts stones of each color still on the board.
--- @param b table
--- @return integer black_count
--- @return integer white_count
local function count_stones(b)
	local nb, nw = 0, 0
	local n = config.BOARD_SIZE
	for r = 1, n do
		for c = 1, n do
			local v = b[r][c]
			if v == config.STONE_BLACK then
				nb = nb + 1
			elseif v == config.STONE_WHITE then
				nw = nw + 1
			end
		end
	end
	return nb, nw
end

--- Marks the game finished and sets a short area-style score line (stones + prisoners).
--- @param g table
function M.finish(g)
	g.over = true
	g.to_play = config.STONE_NONE
	local nb, nw = count_stones(g.board)
	local pb = g.prisoners[config.STONE_BLACK]
	local pw = g.prisoners[config.STONE_WHITE]
	local score_b = nb + pw
	local score_w = nw + pb
	local winner
	if score_b > score_w then
		winner = "Black"
	elseif score_w > score_b then
		winner = "White"
	else
		winner = "Draw"
	end
	g.status = string.format(
		"Game over. Area + prisoners — Black: %d, White: %d (%s). R same mode  M menu.",
		score_b,
		score_w,
		winner
	)
end

return M
