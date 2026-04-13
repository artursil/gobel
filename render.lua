--- Renders the board grid, stones (by kind), incoming queues, and UI.

local cells = require("board")
local config = require("config")
local layout_mod = require("layout")
local rules = require("rules")
local stone_kinds = require("stone_kinds")
local stone_queue = require("stone_queue")

local M = {}

--- Draws the full frame for the current game and layout.
--- @param game table
--- @param layout table
--- @param hover_row integer|nil
--- @param hover_col integer|nil
--- @param show_hover boolean
function M.draw(game, layout, hover_row, hover_col, show_hover)
	local lg = love.graphics
	lg.clear(config.COLOR_BOARD[1], config.COLOR_BOARD[2], config.COLOR_BOARD[3])
	M._draw_score_line(layout, game.board)
	M._draw_grid(layout)
	M._draw_stones(game.board, layout)
	if hover_row and hover_col and show_hover then
		M._draw_hover(layout, hover_row, hover_col)
	end
	M._draw_incoming(game, layout)
	local pb = game.prisoners[config.STONE_BLACK]
	local pw = game.prisoners[config.STONE_WHITE]
	local footer = string.format(
		"Prisoners — Black: %d  White: %d  —  P pass  R same mode  M menu  Esc menu",
		pb,
		pw
	)
	M._draw_status(game.status .. "\n" .. footer, layout)
end

--- Draws weighted liberty scores at the top.
--- @param layout table
--- @param board table
function M._draw_score_line(layout, board)
	local lg = love.graphics
	local sb = rules.unique_liberty_score(board, config.STONE_BLACK)
	local sw = rules.unique_liberty_score(board, config.STONE_WHITE)
	local w = lg.getWidth()
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	local line = string.format(
		"Score (liberties × kind) — Black: %d    White: %d",
		math.floor(sb + 0.5),
		math.floor(sw + 0.5)
	)
	lg.printf(line, 0, layout.score_y, w, "center")
end

--- Draws grid lines between intersections.
--- @param layout table
function M._draw_grid(layout)
	local lg = love.graphics
	lg.setColor(config.COLOR_GRID[1], config.COLOR_GRID[2], config.COLOR_GRID[3])
	lg.setLineWidth(config.GRID_LINE_WIDTH)
	local n = layout.n
	for i = 1, n do
		local x1, y1 = layout_mod.grid_to_pixel(layout, i, 1)
		local x2, y2 = layout_mod.grid_to_pixel(layout, i, n)
		lg.line(x1, y1, x2, y2)
		local xa, ya = layout_mod.grid_to_pixel(layout, 1, i)
		local xb, yb = layout_mod.grid_to_pixel(layout, n, i)
		lg.line(xa, ya, xb, yb)
	end
	lg.setColor(1, 1, 1, 1)
end

--- Draws an X mark centered at (px, py) with given radius stroke.
--- @param px number
--- @param py number
--- @param radius number
--- @param light_on_dark boolean
function M._draw_x_mark(px, py, radius, light_on_dark)
	local lg = love.graphics
	local k = radius * 0.55
	if light_on_dark then
		lg.setColor(0.92, 0.92, 0.94, 1)
	else
		lg.setColor(0.12, 0.12, 0.14, 1)
	end
	lg.setLineWidth(math.max(2, radius * 0.2))
	lg.line(px - k, py - k, px + k, py + k)
	lg.line(px - k, py + k, px + k, py - k)
	lg.setLineWidth(1)
	lg.setColor(1, 1, 1, 1)
end

--- Draws one stone disk and optional kind decoration at board scale.
--- @param px number
--- @param py number
--- @param rad number
--- @param cell table
function M._draw_stone_at(px, py, rad, cell)
	local lg = love.graphics
	if cell.color == config.STONE_BLACK then
		lg.setColor(config.COLOR_BLACK_STONE[1], config.COLOR_BLACK_STONE[2], config.COLOR_BLACK_STONE[3])
	else
		lg.setColor(config.COLOR_WHITE_STONE[1], config.COLOR_WHITE_STONE[2], config.COLOR_WHITE_STONE[3])
	end
	lg.circle("fill", px, py, rad)
	if cell.kind == stone_kinds.X then
		M._draw_x_mark(px, py, rad, cell.color == config.STONE_BLACK)
	end
end

--- Draws a preview stone for the incoming pipeline.
--- @param cx number center x
--- @param cy number center y
--- @param rad number
--- @param chain_color integer
--- @param kind integer
function M._draw_pipeline_stone(cx, cy, rad, chain_color, kind)
	local lg = love.graphics
	if chain_color == config.STONE_BLACK then
		lg.setColor(config.COLOR_BLACK_STONE[1], config.COLOR_BLACK_STONE[2], config.COLOR_BLACK_STONE[3])
	else
		lg.setColor(config.COLOR_WHITE_STONE[1], config.COLOR_WHITE_STONE[2], config.COLOR_WHITE_STONE[3])
	end
	lg.circle("fill", cx, cy, rad)
	if kind == stone_kinds.X then
		M._draw_x_mark(cx, cy, rad, chain_color == config.STONE_BLACK)
	end
end

--- Draws placed stones for every non-empty intersection.
--- @param board table
--- @param layout table
function M._draw_stones(board, layout)
	local lg = love.graphics
	local rad = layout.cell * config.STONE_RADIUS_FACTOR
	local n = layout.n
	for r = 1, n do
		for c = 1, n do
			local cell = board[r][c]
			if not cells.is_empty(cell) then
				local px, py = layout_mod.grid_to_pixel(layout, r, c)
				M._draw_stone_at(px, py, rad, cell)
			end
		end
	end
	lg.setColor(1, 1, 1, 1)
end

--- Draws the next five stone kinds for each player above the status bar.
--- @param game table
--- @param layout table
function M._draw_incoming(game, layout)
	local lg = love.graphics
	local yb = layout.queue_y
	local yw = layout.queue_y + layout.queue_row_step
	local stone_r = 12
	local gap = 10
	local label_w = 108
	local b_kinds = stone_queue.peek_five(game, config.STONE_BLACK)
	local w_kinds = stone_queue.peek_five(game, config.STONE_WHITE)
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	lg.print("Black →", 16, yb + 2)
	lg.print("White →", 16, yw + 2)
	local x0 = 16 + label_w
	for i = 1, 5 do
		local cx = x0 + (i - 1) * (2 * stone_r + gap) + stone_r
		M._draw_pipeline_stone(cx, yb + stone_r + 2, stone_r, config.STONE_BLACK, b_kinds[i])
	end
	for i = 1, 5 do
		local cx = x0 + (i - 1) * (2 * stone_r + gap) + stone_r
		M._draw_pipeline_stone(cx, yw + stone_r + 2, stone_r, config.STONE_WHITE, w_kinds[i])
	end
end

--- Draws a translucent marker under the hovered empty intersection.
--- @param layout table
--- @param row integer
--- @param col integer
function M._draw_hover(layout, row, col)
	local lg = love.graphics
	local px, py = layout_mod.grid_to_pixel(layout, row, col)
	lg.setColor(
		config.COLOR_HIGHLIGHT[1],
		config.COLOR_HIGHLIGHT[2],
		config.COLOR_HIGHLIGHT[3],
		config.COLOR_HIGHLIGHT[4]
	)
	lg.circle("fill", px, py, layout.cell * 0.2)
	lg.setColor(1, 1, 1, 1)
end

--- Draws the status and prisoner counts at the bottom of the window.
--- @param status string
--- @param layout table
function M._draw_status(status, layout)
	local lg = love.graphics
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	local w = lg.getWidth()
	lg.printf(status, 12, layout.chrome_y, w - 24, "left")
end

return M
