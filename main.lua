--- Entry point: menu, LÖVE callbacks, and routing input to game or home.
if os.getenv("DEBUG") then
    require("mobdebug").start()
end
local config = require("config")
local game = require("game")
local home = require("home")
local layout_mod = require("layout")
local match_state = require("match_state")
local render = require("render")
local board = require("board")
local content = require("content")


local screen
local match
local layout
local hover_row
local hover_col
local popup_state
local stone_drag
local card_ui
local stance_ui
local influence_probe
local menu_step
local dropdown_open
local selected_game_type

local function reset_menu_state()
	menu_step = "game_type"
	dropdown_open = false
	selected_game_type = "standard"
end

local function is_popup_open()
	return popup_state.mode ~= "none"
end

--- @return nil
local function reset_popup()
	popup_state = { mode = "none", stone_id = nil, stones = {}, focus_index = nil, anchor_rect = nil, selected_slot = nil, row = nil, col = nil, owner = nil, game_state = nil }
end

--- @return nil
local function close_selector_popup()
	reset_popup()
end

local function open_board_stone_popup(row, col)
	local cell = match.board[row] and match.board[row][col]
	if board.is_empty(cell) then
		return false
	end
	popup_state.mode = "board-stone-info"
	popup_state.stone_id = cell.kind
	popup_state.row = row
	popup_state.col = col
	popup_state.owner = cell.color
	popup_state.game_state = match
	return true
end

--- @param active table
--- @param slot_index integer
--- @return boolean
local function open_selector_popup(active, slot_index)
	local stone_id = active.stones.playable_stones[slot_index]
	if not stone_id then
		return false
	end
	if not game.select_stone(match, stone_id, slot_index) then
		return false
	end
	local rects = layout_mod.stone_chip_rects(layout, #active.stones.playable_stones)
	popup_state.mode = "selector-details"
	popup_state.stone_id = stone_id
	popup_state.anchor_rect = rects[slot_index]
	popup_state.selected_slot = slot_index
	return true
end

--- @param active table
--- @return nil
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

--- @param active table
--- @return nil
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

local function open_discard_popup(active)
	popup_state.mode = "discard-browser"
	popup_state.cards = {}
	popup_state.played_cards = {}
	local discarded = active.cards.discard.ids
	for i = 1, #discarded do
		popup_state.played_cards[i] = discarded[i]
	end
	if #popup_state.played_cards > 0 then
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

--- @param x number
--- @param y number
--- @return boolean
local function handle_score_box_click(x, y)
	if x >= layout.score_player.x and x <= layout.score_player.x + layout.score_player.w and
	   y >= layout.score_player.y and y <= layout.score_player.y + layout.score_player.h then
		render.toggle_score_display_mode()
		return true
	end
	if x >= layout.score_opponent.x and x <= layout.score_opponent.x + layout.score_opponent.w and
	   y >= layout.score_opponent.y and y <= layout.score_opponent.y + layout.score_opponent.h then
		render.toggle_score_display_mode()
		return true
	end
	return false
end

--- @param x number
--- @param y number
--- @param active table
--- @param stone_count integer
--- @return boolean
local function handle_open_popup_click(x, y, active, stone_count)
	if is_popup_open() then
		return false
	end
	local action_rects = layout_mod.player_action_icon_rects(layout)
	local bowl = action_rects[1]
	if x >= bowl.x and x <= bowl.x + bowl.w and y >= bowl.y and y <= bowl.y + bowl.h then
		open_pouch_popup(active)
		return true
	end
	local deck = action_rects[2]
	if x >= deck.x and x <= deck.x + deck.w and y >= deck.y and y <= deck.y + deck.h then
		open_deck_popup(active)
		return true
	end
	local discard = layout_mod.discard_icon_rect(layout)
	if x >= discard.x and x <= discard.x + discard.w and y >= discard.y and y <= discard.y + discard.h then
		open_discard_popup(active)
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

--- @param x number
--- @param y number
--- @param active table
--- @param stone_count integer
--- @return boolean
local function handle_active_popup_click(x, y, active, stone_count)
	if popup_state.mode == "selector-details" then
		local stone_index = layout_mod.stone_index_at(layout, x, y, stone_count)
		if not stone_index then
			close_selector_popup()
			return false
		end
		if popup_state.selected_slot ~= stone_index then
			open_selector_popup(active, stone_index)
		end
		return true
	end
	if popup_state.mode == "board-stone-info" then
		local popup_hit = render.popup_hit_test(layout, popup_state, x, y)
		if popup_hit.kind == "consume" then
			return false
		end
		if popup_hit.kind == "none" then
			reset_popup()
			return false
		end
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

--- @return nil
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

--- @return nil
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

local function reset_stance_ui()
	stance_ui = {
		owner_key = nil,
		index = nil,
		drag_active = false,
		drag_index = nil,
		drag_was_selected = false,
		start_x = 0,
		start_y = 0,
		current_x = 0,
		current_y = 0,
		moved = false,
	}
end

local function reset_influence_probe()
	influence_probe = nil
end

local function update_influence_probe(dt)
	if not influence_probe then
		return
	end
	influence_probe.remaining = (influence_probe.remaining or 0) - dt
	if influence_probe.remaining <= 0 then
		reset_influence_probe()
	end
end

local function clear_influence_probe_on_board_click(x, y)
	local row, col = layout_mod.pixel_to_grid(layout, x, y)
	if not row or not col then
		return false
	end
	reset_influence_probe()
	return true
end

local function handle_influence_probe_click(x, y)
	if screen ~= "play" or not match then
		return false
	end
	local row, col = layout_mod.pixel_to_grid(layout, x, y)
	if not row or not col then
		reset_influence_probe()
		return true
	end
	local cell = match.board[row] and match.board[row][col]
	if not cell or not board.is_empty(cell) then
		reset_influence_probe()
		return true
	end
	local by_row = match.territory_decision_sources and match.territory_decision_sources[row]
	local source = by_row and by_row[col] or nil
	if not source or not source.contributors then
		reset_influence_probe()
		return true
	end
	influence_probe = {
		row = row,
		col = col,
		owner = source.owner,
		contributors = source.contributors,
		remaining = 3,
	}
	return true
end

local function owner_color_from_key(owner_key)
	if owner_key == config.OWNER_BLACK then
		return "black"
	end
	return "white"
end

local function swap_stance_positions(owner_key, from_index, to_index)
	if not from_index or not to_index or from_index == to_index then
		return
	end
	local player = match_state.player_for_color(match, owner_color_from_key(owner_key))
	local fixed_count = #player.stances.fixed
	local base_count = fixed_count + #player.stances.swappable
	if from_index > base_count or to_index > base_count then
		return
	end
	local combined = {}
	for i = 1, fixed_count do
		combined[#combined + 1] = player.stances.fixed[i]
	end
	for i = 1, #player.stances.swappable do
		combined[#combined + 1] = player.stances.swappable[i]
	end
	combined[from_index], combined[to_index] = combined[to_index], combined[from_index]
	for i = 1, fixed_count do
		player.stances.fixed[i] = combined[i]
	end
	for i = fixed_count + 1, #combined do
		player.stances.swappable[i - fixed_count] = combined[i]
	end
end

local function begin_stance_drag(x, y)
	local hit = render.stance_hit_test(match, layout, x, y)
	if hit.kind == "stance_card" then
		stance_ui.drag_active = true
		stance_ui.drag_index = hit.index
		stance_ui.owner_key = hit.owner_key
		stance_ui.start_x = x
		stance_ui.start_y = y
		stance_ui.current_x = x
		stance_ui.current_y = y
		stance_ui.moved = false
		stance_ui.drag_was_selected = (stance_ui.owner_key == hit.owner_key and stance_ui.index == hit.index)
		return true
	end
	if stance_ui.index and hit.kind == "none" then
		reset_stance_ui()
		return false
	end
	return hit.kind == "stance_panel"
end

local function end_stance_drag(x, y)
	if not stance_ui.drag_active then
		return false
	end
	local owner_key = stance_ui.owner_key
	local drag_index = stance_ui.drag_index
	local moved = stance_ui.moved
	stance_ui.drag_active = false
	stance_ui.drag_index = nil
	stance_ui.moved = false
	if moved then
		local hit = render.stance_hit_test(match, layout, x, y)
		if hit.kind == "stance_card" and hit.owner_key == owner_key then
			swap_stance_positions(owner_key, drag_index, hit.index)
		end
		return true
	end
	if stance_ui.owner_key == owner_key and stance_ui.index == drag_index then
		reset_stance_ui()
	else
		stance_ui.owner_key = owner_key
		stance_ui.index = drag_index
	end
	return true
end

--- @param x number
--- @param y number
--- @param active table
--- @return boolean
local function handle_card_press(x, y, active)
	if popup_state.mode == "selector-details" then
		close_selector_popup()
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
		return true
	end
	if not card_ui.selected_index then
		return false
	end
	local use = layout_mod.card_use_button_rect(layout)
	if x >= use.x and x <= use.x + use.w and y >= use.y and y <= use.y + use.h then
		local ok = game.play_card(match, card_ui.selected_index)
		if ok then
			card_ui.selected_index = nil
		end
		return true
	end
	card_ui.selected_index = nil
	return true
end

--- @param x number
--- @param y number
--- @return nil
local function handle_board_press(x, y)
	local row, col = layout_mod.pixel_to_grid(layout, x, y)
	if not row then
		return
	end
	local cell = match.board[row] and match.board[row][col]
	if cell and not board.is_empty(cell) then
		match.selected_card_target = {
			row = row,
			col = col,
			stone_id = cell.kind,
			stone_color = cell.color,
		}
		local active = match_state.player_for_color(match, match.to_play)
		local selected_index = card_ui.selected_index
		local card_id = selected_index and active.cards.hand.ids[selected_index] or nil
		local card_def = card_id and content.get_card(card_id) or nil
		if card_def and card_def.targeting and card_def.targeting.kind == "board_stone" then
			game.select_board_target(match, row, col)
		end
		open_board_stone_popup(row, col)
		return
	end
	game.player_move(match, row, col)
end

--- @return nil
local function reset_to_menu()
	screen = "menu"
	match = nil
	reset_menu_state()
	hover_row, hover_col = nil, nil
	reset_popup()
	reset_stone_drag()
	reset_card_ui()
	reset_stance_ui()
	reset_influence_probe()
end

--- Seeds RNG, fonts, and opens the home screen.
function love.load()
	love.graphics.setFont(love.graphics.newFont(18))
	local w, h = love.graphics.getDimensions()
	layout = layout_mod.from_window(w, h)
	screen = "menu"
	match = nil
	reset_menu_state()
	hover_row, hover_col = nil, nil
	reset_popup()
	reset_stone_drag()
	reset_card_ui()
	reset_stance_ui()
	reset_influence_probe()
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
		update_influence_probe(dt)
		render.update(dt, match, layout)
		if not render.is_score_animating() then
			game.tick_ai(match, dt)
		end
	end
end

--- Draws either the home screen or the active match.
function love.draw()
	local w, h = love.graphics.getDimensions()
	if screen == "menu" then
		if menu_step == "game_type" then
			home.draw_game_type_menu(w, h, dropdown_open, selected_game_type)
		else
			home.draw_match_menu(w, h, selected_game_type)
		end
		return
	end
	local hr, hc = hover_row, hover_col
	local show_hover = game.is_human_turn(match)
	render.set_card_ui_state(card_ui)
	render.set_stance_ui_state(stance_ui)
	render.set_stone_drag_state(stone_drag)
	render.set_influence_probe_state(influence_probe)
	render.draw(match, layout, hr, hc, show_hover, popup_state, stone_drag)
end

--- Routes clicks to menu buttons or board placement.
--- @param x number
--- @param y number
--- @param button integer
function love.mousepressed(x, y, button)
	if button == 2 then
		clear_influence_probe_on_board_click(x, y)
		handle_influence_probe_click(x, y)
		return
	end
	if button ~= 1 then
		return
	end
	local w, h = love.graphics.getDimensions()
	if screen == "menu" then
		if menu_step == "game_type" then
			local pick = home.hit_test_game_type(x, y, w, h, dropdown_open, selected_game_type)
			if pick == "dropdown_open" then
				dropdown_open = true
				return
			elseif pick == "dropdown_close" then
				dropdown_open = false
				return
			elseif pick and pick:sub(1, 10) == "game_type:" then
				selected_game_type = pick:sub(11)
				dropdown_open = false
				menu_step = "match"
				return
			end
		elseif menu_step == "match" then
			local pick = home.hit_test_match(x, y, w, h)
			if pick == "pvp" or pick == "pvc" then
				match = game.new(pick, selected_game_type, "regional")
				screen = "play"
				layout = layout_mod.from_window(w, h)
				reset_popup()
				reset_stone_drag()
				reset_card_ui()
				reset_stance_ui()
				reset_influence_probe()
			end
			return
		end
		return
	end
	if match.over then
		return
	end
	clear_influence_probe_on_board_click(x, y)
	if stone_drag.active then
		return
	end
	if stance_ui.drag_active then
		return
	end
	local active = match_state.player_for_color(match, match.to_play)
	local stone_count = #active.stones.playable_stones
	if handle_score_box_click(x, y) then
		return
	end
	if begin_stance_drag(x, y) then
		return
	end
	if handle_active_popup_click(x, y, active, stone_count) then
		return
	end
	if handle_open_popup_click(x, y, active, stone_count) then
		return
	end
	if handle_card_press(x, y, active) then
		return
	end
	handle_board_press(x, y)
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
	if stance_ui.drag_active then
		stance_ui.current_x = x
		stance_ui.current_y = y
		local dx = x - stance_ui.start_x
		local dy = y - stance_ui.start_y
		if (dx * dx + dy * dy) > 64 then
			stance_ui.moved = true
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
				game.select_stone(match, stone_id, source_index)
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
	if end_stance_drag(x, y) then
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
			if menu_step == "match" then
				menu_step = "territory"
			else
				love.event.quit()
			end
		else
			reset_to_menu()
		end
		return
	end
	if screen == "menu" then
		return
	end
	if is_popup_open() then
		return
	end
	if key == "m" then
		reset_to_menu()
		return
	end
	if key == "r" and match then
		local kind = match.match_kind
		match = game.new(kind, match.territory_mode)
		layout = layout_mod.from_window(w, h)
		reset_popup()
		reset_stone_drag()
		reset_card_ui()
		reset_stance_ui()
		reset_influence_probe()
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
