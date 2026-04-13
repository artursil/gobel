--- Entry point: menu, LÖVE callbacks, and routing input to game or home.

local game = require("game")
local home = require("home")
local layout_mod = require("layout")
local render = require("render")

local screen
local match
local layout
local hover_row
local hover_col

--- Seeds RNG, fonts, and opens the home screen.
function love.load()
	love.graphics.setFont(love.graphics.newFont(18))
	local w, h = love.graphics.getDimensions()
	layout = layout_mod.from_window(w, h)
	screen = "menu"
	match = nil
	hover_row, hover_col = nil, nil
	love.math.setRandomSeed(love.timer.getTime() * 1000000 + os.time())
end

--- Resizes board layout when the window changes during play.
--- @param w number
--- @param h number
function love.resize(w, h)
	if screen == "play" then
		layout = layout_mod.from_window(w, h)
	end
end

--- Advances the bot when in a player-vs-bot match.
--- @param dt number
function love.update(dt)
	if screen == "play" and match then
		game.tick_ai(match, dt)
	end
end

--- Draws either the home screen or the active match.
function love.draw()
	local w, h = love.graphics.getDimensions()
	if screen == "menu" then
		home.draw(w, h)
		return
	end
	local hr, hc = hover_row, hover_col
	local show_hover = game.is_human_turn(match)
	render.draw(match, layout, hr, hc, show_hover)
end

--- Routes clicks to menu buttons or board placement.
--- @param x number
--- @param y number
--- @param button integer
function love.mousepressed(x, y, button)
	if button ~= 1 then
		return
	end
	local w, h = love.graphics.getDimensions()
	if screen == "menu" then
		local pick = home.hit_test(x, y, w, h)
		if pick == "pvp" then
			match = game.new("pvp")
			screen = "play"
			layout = layout_mod.from_window(w, h)
		elseif pick == "pvc" then
			match = game.new("pvc")
			screen = "play"
			layout = layout_mod.from_window(w, h)
		end
		return
	end
	if match.over then
		return
	end
	local r, c = layout_mod.pixel_to_grid(layout, x, y)
	if not r then
		return
	end
	game.player_move(match, r, c)
end

--- Tracks hover for the placement preview on the board only.
--- @param x number
--- @param y number
function love.mousemoved(x, y)
	if screen ~= "play" then
		hover_row, hover_col = nil, nil
		return
	end
	hover_row, hover_col = layout_mod.pixel_to_grid(layout, x, y)
end

--- Escape toggles menu vs quit; P pass; R restart same mode; M opens menu from play.
--- @param key love.KeyConstant
function love.keypressed(key)
	local w, h = love.graphics.getDimensions()
	if key == "escape" then
		if screen == "menu" then
			love.event.quit()
		else
			screen = "menu"
			match = nil
			hover_row, hover_col = nil, nil
		end
		return
	end
	if screen == "menu" then
		return
	end
	if key == "m" then
		screen = "menu"
		match = nil
		hover_row, hover_col = nil, nil
		return
	end
	if key == "r" and match then
		local kind = match.match_kind
		match = game.new(kind)
		layout = layout_mod.from_window(w, h)
		return
	end
	if key == "p" and match then
		game.player_pass(match)
	end
end
