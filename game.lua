--- Match flow: turns, passes, scoring summary, and AI scheduling.

local ai = require("ai")
local board = require("board")
local config = require("config")
local rules = require("rules")

local M = {}

--- Builds a fresh game with human as Black and a random-move White opponent.
--- @return table
function M.new()
	return {
		board = board.new(),
		to_play = config.STONE_BLACK,
		ko_ban = nil,
		prisoners = { [config.STONE_BLACK] = 0, [config.STONE_WHITE] = 0 },
		consecutive_passes = 0,
		over = false,
		status = "Your turn (Black). Click an empty intersection.",
		ai_delay = 0,
	}
end

--- Applies a human stone play when it is Black's turn and the move is legal.
--- @param g table
--- @param row integer
--- @param col integer
--- @return boolean
function M.human_play(g, row, col)
	if g.over or g.to_play ~= config.HUMAN_COLOR then
		return false
	end
	local ok, new_board, new_ko, caps = rules.try_play(g.board, row, col, config.HUMAN_COLOR, g.ko_ban)
	if not ok then
		g.status = "Illegal move."
		return false
	end
	g.board = new_board
	g.ko_ban = new_ko
	g.prisoners[config.HUMAN_COLOR] = g.prisoners[config.HUMAN_COLOR] + caps
	g.consecutive_passes = 0
	g.to_play = config.AI_COLOR
	g.status = "White is thinking…"
	g.ai_delay = 0.35
	return true
end

--- Records a pass when it is the human's turn; may end the game or hand over to the AI.
--- @param g table
function M.human_pass(g)
	if g.over or g.to_play ~= config.HUMAN_COLOR then
		return
	end
	g.consecutive_passes = g.consecutive_passes + 1
	if g.consecutive_passes >= 2 then
		M.finish(g)
		return
	end
	g.to_play = config.AI_COLOR
	g.status = "You passed. White to play."
	g.ai_delay = 0.35
end

--- Runs the random AI when it is White's turn; respects optional think delay.
--- @param g table
--- @param dt number
function M.tick_ai(g, dt)
	if g.over or g.to_play ~= config.AI_COLOR then
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
		g.to_play = config.HUMAN_COLOR
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
	g.to_play = config.HUMAN_COLOR
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
		"Game over. Area + prisoners — Black: %d, White: %d (%s). R to restart.",
		score_b,
		score_w,
		winner
	)
end

return M
