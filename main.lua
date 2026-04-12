--- Entry point: wires LÖVE callbacks to game logic, input, and drawing.

local config = require("config")
local game = require("game")
local layout_mod = require("layout")
local render = require("render")

local state
local layout
local hover_row
local hover_col

--- Seeds RNG, font, and initial match state.
function love.load()
	love.graphics.setFont(love.graphics.newFont(18))
	local w, h = love.graphics.getDimensions()
	layout = layout_mod.from_window(w, h)
	state = game.new()
	love.math.setRandomSeed(love.timer.getTime() * 1000000 + os.time())
end

--- Resizes layout when the window changes.
--- @param w number
--- @param h number
function love.resize(w, h)
	layout = layout_mod.from_window(w, h)
end

--- Advances the random opponent after a short delay.
--- @param dt number
function love.update(dt)
	game.tick_ai(state, dt)
end

--- Paints the board and status; shows hover only on human turns.
function love.draw()
	local hr, hc = hover_row, hover_col
	if state.over or state.to_play ~= config.HUMAN_COLOR then
		hr, hc = nil, nil
	end
	render.draw(state, layout, hr, hc)
end

--- Maps a mouse click to a human move when it is Black's turn.
--- @param x number
--- @param y number
--- @param button integer
function love.mousepressed(x, y, button)
	if button ~= 1 or state.over then
		return
	end
	local r, c = layout_mod.pixel_to_grid(layout, x, y)
	if not r then
		return
	end
	game.human_play(state, r, c)
end

--- Tracks hovered intersection for the placement preview.
--- @param x number
--- @param y number
function love.mousemoved(x, y)
	hover_row, hover_col = layout_mod.pixel_to_grid(layout, x, y)
end

--- Pass (P), restart (R); Escape quits.
--- @param key love.KeyConstant
function love.keypressed(key)
	if key == "escape" then
		love.event.quit()
		return
	end
	if key == "r" then
		state = game.new()
		return
	end
	if key == "p" then
		game.human_pass(state)
	end
end
