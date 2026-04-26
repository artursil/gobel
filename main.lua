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
local stone_drag
local card_ui

local function is_popup_open()
	return popup_state.mode ~= "none"
end

local function reset_popup()
	popup_state = { mode = "none", stone_id = nil, stones = {}, focus_index = nil, anchor_rect = nil, selected_slot = nil }
end

local function close_selector_popup()
	reset_popup()
end

local function open_selector_popup(active, slot_index)
	local stone_id = active.stones.playable_stones[slot_index]
	if not stone_id then
		return false
	end
	game.select_stone(match, stone_id)
	local rects = layout_mod.stone_chip_rects(layout, #active.stones.playable_stones)
	popup_state.mode = "selector-details"
	popup_state.stone_id = stone_id
	popup_state.anchor_rect = rects[slot_index]
	popup_state.selected_slot = slot_index
	return true
end

local function open_pouch_popup(active)
	local ids = active.stones.pouch.ids
	popup_state.mode = "pouch-browser"
	popup_state.stones = {}
	for i = 1, #ids do
		popup_state.stones[i] = ids[i]
	end
	popup_state.focus_index = (#popup_state.stones > 0) and 1 or nil
	popup_state.stone_id = nil
	popup_state.anchor_rect = nil
	popup_state.selected_slot = nil
end

local function open_deck_popup(active)
	local ids = active.cards.deck.ids
	popup_state.mode = "deck-browser"
	popup_state.cards = {}
	for i = 1, #ids do
		popup_state.cards[i] = ids[i]
	end
	popup_state.played_cards = {}
	local played = active.cards.discard.ids
	for i = 1, #played do
		popup_state.played_cards[i] = played[i]
	end
	if #popup_state.cards > 0 then
		popup_state.focus_group = "deck"
		popup_state.focus_index = 1
	elseif #popup_state.played_cards > 0 then
		popup_state.focus_group = "played"
		popup_state.focus_index = 1
	else
		popup_state.focus_group = nil
		popup_state.focus_index = nil
	end
	popup_state.stone_id = nil
	popup_state.anchor_rect = nil
	popup_state.selected_slot = nil
end

local function handle_open_popup_click(x, y, active, stone_count)
	if is_popup_open() then
		return false
	end
	if x >= layout.pouch_panel.x and x <= layout.pouch_panel.x + layout.pouch_panel.w and y >= layout.pouch_panel.y and y <= layout.pouch_panel.y + layout.pouch_panel.h then
		open_pouch_popup(active)
		return true
	end
	if x >= layout.deck_panel.x and x <= layout.deck_panel.x + layout.deck_panel.w and y >= layout.deck_panel.y and y <= layout.deck_panel.y + layout.deck_panel.h then
		open_deck_popup(active)
		return true
	end
	local stone_index = layout_mod.stone_index_at(layout, x, y, stone_count)
	if not stone_index then
		return false
	end
	local stone_id = active.stones.playable_stones[stone_index]
	if stone_id then
		stone_drag.active = true
		stone_drag.stone_id = stone_id
		stone_drag.source_index = stone_index
		stone_drag.start_x = x
		stone_drag.start_y = y
		stone_drag.current_x = x
		stone_drag.current_y = y
		stone_drag.moved = false
	end
	return true
end

local function handle_active_popup_click(x, y, active, stone_count)
	if popup_state.mode == "selector-details" then
		local stone_index = layout_mod.stone_index_at(layout, x, y, stone_count)
		if not stone_index then
			close_selector_popup()
			return true
		end
		if popup_state.selected_slot ~= stone_index then
			open_selector_popup(active, stone_index)
		end
		return true
	end
	if not is_popup_open() then
		return false
	end
	local popup_hit = render.popup_hit_test(layout, popup_state, x, y)
	if popup_hit.kind == "close" then
		reset_popup()
		return true
	end
	if popup_hit.kind == "pouch_stone" then
		popup_state.focus_index = popup_hit.index
		return true
	end
	if popup_hit.kind == "deck_card" then
		popup_state.focus_group = popup_hit.group
		popup_state.focus_index = popup_hit.index
		return true
	end
	return true
end

local function reset_stone_drag()
	stone_drag = {
		active = false,
		stone_id = nil,
		source_index = nil,
		start_x = 0,
		start_y = 0,
		current_x = 0,
		current_y = 0,
		moved = false,
	}
end

local function reset_card_ui()
	card_ui = {
		selected_index = nil,
		drag_active = false,
		drag_index = nil,
		start_x = 0,
		start_y = 0,
		current_x = 0,
		current_y = 0,
		moved = false,
	}
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
	reset_stone_drag()
	reset_card_ui()
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
	render.set_card_ui_state(card_ui)
	render.draw(match, layout, hr, hc, show_hover, popup_state, stone_drag)
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
		if pick == "pvp" or pick == "pvc" then
			match = game.new(pick)
			screen = "play"
			layout = layout_mod.from_window(w, h)
			reset_popup()
			reset_stone_drag()
			reset_card_ui()
		end
		return
	end
	if match.over then
		return
	end
	if stone_drag.active then
		return
	end
	local active = match_state.player_for_color(match, match.to_play)
	local stone_count = #active.stones.playable_stones
	if handle_active_popup_click(x, y, active, stone_count) then
		return
	end
	if handle_open_popup_click(x, y, active, stone_count) then
		return
	end
	local hand_count = #active.cards.hand.ids
	if card_ui.selected_index and card_ui.selected_index > hand_count then
		card_ui.selected_index = nil
	end
	local hand_index = layout_mod.hand_index_at(layout, x, y, hand_count)
	if hand_index then
		card_ui.selected_index = hand_index
		card_ui.drag_active = true
		card_ui.drag_index = hand_index
		card_ui.start_x = x
		card_ui.start_y = y
		card_ui.current_x = x
		card_ui.current_y = y
		card_ui.moved = false
		return
	end
	if card_ui.selected_index then
		local use = layout_mod.card_use_button_rect(layout)
		if x >= use.x and x <= use.x + use.w and y >= use.y and y <= use.y + use.h then
			local ok = game.play_card(match, card_ui.selected_index)
			if ok then
				card_ui.selected_index = nil
			end
			return
		end
		card_ui.selected_index = nil
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
	if stone_drag.active then
		stone_drag.current_x = x
		stone_drag.current_y = y
		local dx = x - stone_drag.start_x
		local dy = y - stone_drag.start_y
		if (dx * dx + dy * dy) > 64 then
			stone_drag.moved = true
			if popup_state.mode == "selector-details" then
				close_selector_popup()
			end
		end
	end
	if card_ui.drag_active then
		card_ui.current_x = x
		card_ui.current_y = y
		local dx = x - card_ui.start_x
		local dy = y - card_ui.start_y
		if (dx * dx + dy * dy) > 64 then
			card_ui.moved = true
		end
	end
	hover_row, hover_col = layout_mod.pixel_to_grid(layout, x, y)
end

function love.mousereleased(x, y, button)
	if button ~= 1 or screen ~= "play" or not match then
		return
	end
	if stone_drag.active then
		local active = match_state.player_for_color(match, match.to_play)
		local stone_count = #active.stones.playable_stones
		local source_index = stone_drag.source_index
		local stone_id = stone_drag.stone_id
		if stone_drag.moved then
			if stone_id then
				game.select_stone(match, stone_id)
			end
			local r, c = layout_mod.pixel_to_grid(layout, x, y)
			if r and c then
				game.player_move(match, r, c)
			end
			reset_stone_drag()
			return
		end
		if source_index and source_index <= stone_count and stone_id then
			open_selector_popup(active, source_index)
		end
		reset_stone_drag()
		return
	end
	if card_ui.drag_active then
		if card_ui.moved and card_ui.drag_index then
			local use = layout_mod.card_use_button_rect(layout)
			if x >= use.x and x <= use.x + use.w and y >= use.y and y <= use.y + use.h then
				local ok = game.play_card(match, card_ui.drag_index)
				if ok then
					card_ui.selected_index = nil
				end
			end
		elseif card_ui.drag_index then
			card_ui.selected_index = card_ui.drag_index
		end
		card_ui.drag_active = false
		card_ui.drag_index = nil
		card_ui.moved = false
	end
end

--- Escape toggles menu vs quit; P pass; R restart same mode; M opens menu from play.
--- @param key love.KeyConstant
function love.keypressed(key)
	local w, h = love.graphics.getDimensions()
	if is_popup_open() and key == "escape" then
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
			reset_stone_drag()
			reset_card_ui()
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
		reset_stone_drag()
		reset_card_ui()
		return
	end
	if key == "r" and match then
		local kind = match.match_kind
		match = game.new(kind)
		layout = layout_mod.from_window(w, h)
		reset_popup()
		reset_stone_drag()
		reset_card_ui()
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
