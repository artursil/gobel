--- Renders the board grid, stones, last status line, and optional hover marker.

local config = require("config")
local layout_mod = require("layout")
local rules = require("rules")

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
	local pb = game.prisoners[config.STONE_BLACK]
	local pw = game.prisoners[config.STONE_WHITE]
	local footer = string.format(
		"Prisoners — Black: %d  White: %d  —  P pass  R same mode  M menu  Esc menu",
		pb,
		pw
	)
	M._draw_status(game.status .. "\n" .. footer, layout)
end

--- Draws live liberty-based scores centered under the top margin.
--- @param layout table
--- @param board table
function M._draw_score_line(layout, board)
	local lg = love.graphics
	local sb = rules.unique_liberty_score(board, config.STONE_BLACK)
	local sw = rules.unique_liberty_score(board, config.STONE_WHITE)
	local w = lg.getWidth()
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	local line = string.format("Score (unique liberties) — Black: %d    White: %d", sb, sw)
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

--- Draws placed stones for every non-empty intersection.
--- @param board table
--- @param layout table
function M._draw_stones(board, layout)
	local lg = love.graphics
	local rad = layout.cell * config.STONE_RADIUS_FACTOR
	local n = layout.n
	for r = 1, n do
		for c = 1, n do
			local v = board[r][c]
			if v ~= config.STONE_NONE then
				local px, py = layout_mod.grid_to_pixel(layout, r, c)
				if v == config.STONE_BLACK then
					lg.setColor(config.COLOR_BLACK_STONE[1], config.COLOR_BLACK_STONE[2], config.COLOR_BLACK_STONE[3])
				else
					lg.setColor(config.COLOR_WHITE_STONE[1], config.COLOR_WHITE_STONE[2], config.COLOR_WHITE_STONE[3])
				end
				lg.circle("fill", px, py, rad)
			end
		end
	end
	lg.setColor(1, 1, 1, 1)
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
