--- Entry point: menu, LÖVE callbacks, and routing input to game or home.

local game = require("game")
local home = require("home")
local layout_mod = require("layout")
local match_state = require("match_state")
local render = require("render")

local screen
local match
local layout
local hover_row
local hover_col
local popup_state

local function reset_popup()
	popup_state = { mode = "none", stone_id = nil, stones = {}, focus_index = nil, anchor_rect = nil, selected_slot = nil }
end

local function close_selector_popup()
	popup_state.mode = "none"
	popup_state.stone_id = nil
	popup_state.anchor_rect = nil
end

--- Seeds RNG, fonts, and opens the home screen.
function love.load()
	love.graphics.setFont(love.graphics.newFont(18))
	local w, h = love.graphics.getDimensions()
	layout = layout_mod.from_window(w, h)
	screen = "menu"
	match = nil
	hover_row, hover_col = nil, nil
	reset_popup()
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
	render.draw(match, layout, hr, hc, show_hover, popup_state)
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
			reset_popup()
		elseif pick == "pvc" then
			match = game.new("pvc")
			screen = "play"
			layout = layout_mod.from_window(w, h)
			reset_popup()
		end
		return
	end
	if match.over then
		return
	end
	local active = match_state.player_for_color(match, match.to_play)
	local stone_count = #active.stones.playable_stones
	if popup_state.mode == "selector-details" then
		local stone_index = layout_mod.stone_index_at(layout, x, y, stone_count)
		if not stone_index then
			close_selector_popup()
		else
			local stone_id = active.stones.playable_stones[stone_index]
			if not stone_id then
				close_selector_popup()
				return
			end
			if popup_state.selected_slot ~= stone_index then
				game.select_stone(match, stone_id)
				popup_state.mode = "selector-details"
				popup_state.stone_id = stone_id
				local rects = layout_mod.stone_chip_rects(layout, stone_count)
				popup_state.anchor_rect = rects[stone_index]
				popup_state.selected_slot = stone_index
			end
			return
		end
	end
	if popup_state.mode ~= "none" then
		local popup_hit = render.popup_hit_test(layout, popup_state, x, y)
		if popup_hit.kind == "close" then
			reset_popup()
			return
		end
		if popup_hit.kind == "pouch_stone" then
			popup_state.focus_index = popup_hit.index
			return
		end
		return
	end
	if x >= layout.pouch_panel.x and x <= layout.pouch_panel.x + layout.pouch_panel.w and y >= layout.pouch_panel.y and y <= layout.pouch_panel.y + layout.pouch_panel.h then
		popup_state.mode = "pouch-browser"
		popup_state.stones = {}
		local ids = active.stones.pouch.ids
		for i = 1, #ids do
			popup_state.stones[i] = ids[i]
		end
		popup_state.focus_index = (#popup_state.stones > 0) and 1 or nil
		return
	end
	local stone_count = #active.stones.playable_stones
	local stone_index = layout_mod.stone_index_at(layout, x, y, stone_count)
	if stone_index then
		local stone_id = active.stones.playable_stones[stone_index]
		if stone_id then
			game.select_stone(match, stone_id)
			popup_state.mode = "selector-details"
			popup_state.stone_id = stone_id
			local rects = layout_mod.stone_chip_rects(layout, stone_count)
			popup_state.anchor_rect = rects[stone_index]
			popup_state.selected_slot = stone_index
		end
		return
	end
	local hand_count = #active.cards.hand.ids
	local hand_index = layout_mod.hand_index_at(layout, x, y, hand_count)
	if hand_index then
		game.play_card(match, hand_index)
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
	if popup_state.mode ~= "none" and key == "escape" then
		reset_popup()
		return
	end
	if key == "escape" then
		if screen == "menu" then
			love.event.quit()
		else
			screen = "menu"
			match = nil
			hover_row, hover_col = nil, nil
			reset_popup()
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
		reset_popup()
		return
	end
	if key == "r" and match then
		local kind = match.match_kind
		match = game.new(kind)
		layout = layout_mod.from_window(w, h)
		reset_popup()
		return
	end
	if key == "p" and match then
		game.player_pass(match)
		return
	end
	if match and key >= "1" and key <= "5" then
		game.play_card(match, tonumber(key))
	end
end
