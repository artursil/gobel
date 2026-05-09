local cells = require("board")
local config = require("config")
local content = require("content")
local layout_mod = require("layout")
local match_state = require("match_state")
local messages = require("messages")
local stances = require("stances")
local pouch = require("pouch")

local M = {}
local SCORE_ANIM_BASE_DURATION = 0.45
local score_anim_font = nil
local sprite_cache = {}
M._score_anim = {
	queue = {},
	current = nil,
	remaining = 0,
	duration = 0,
}
M._score_display_mode = "simple"
M._stone_draw_anim = {
	queue = {},
	current = nil,
	elapsed = 0,
	duration = 0.22,
}

local function ease_out_cubic(t)
	local inv = 1 - t
	return 1 - inv * inv * inv
end

local function inside(rect, x, y)
	return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function draw_panel(box)
	local lg = love.graphics
	local c = config.COLOR_SCORE_PANEL
	lg.setColor(c[1], c[2], c[3], c[4])
	lg.rectangle("fill", box.x, box.y, box.w, box.h, 8, 8)
	lg.setColor(config.COLOR_GRID[1], config.COLOR_GRID[2], config.COLOR_GRID[3])
	lg.rectangle("line", box.x, box.y, box.w, box.h, 8, 8)
end

local function get_ui_sprite(name)
	if sprite_cache[name] ~= nil then
		return sprite_cache[name]
	end
	local ok, image = pcall(love.graphics.newImage, "sprites/" .. name .. ".png")
	sprite_cache[name] = ok and image or false
	return sprite_cache[name]
end

local function draw_icon_or_fallback(name, rect)
	local lg = love.graphics
	local img = get_ui_sprite(name)
	if img and img ~= false then
		lg.setColor(1, 1, 1, 1)
		lg.draw(img, rect.x, rect.y, 0, rect.w / img:getWidth(), rect.h / img:getHeight())
		return
	end
	lg.setColor(0.8, 0.8, 0.82, 0.7)
	lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
	lg.setColor(0.15, 0.15, 0.2, 1)
	lg.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
	lg.printf(name, rect.x + 4, rect.y + math.floor(rect.h * 0.35), rect.w - 8, "center")
end

--- Draws full-screen board background image if available.
--- Falls back to solid board color when sprite is missing.
--- @return nil
local function draw_game_background()
	local lg = love.graphics
	local bg = get_ui_sprite("background_2_light")
	if bg and bg ~= false then
		local w = lg.getWidth()
		local h = lg.getHeight()
		lg.clear(0, 0, 0, 1)
		lg.setColor(1, 1, 1, 1)
		lg.draw(bg, 0, 0, 0, w / bg:getWidth(), h / bg:getHeight())
		return
	end
	lg.clear(config.COLOR_BOARD[1], config.COLOR_BOARD[2], config.COLOR_BOARD[3])
end

local function draw_stone_graphic(draw_key, x, y, w, h, color)
	local lg = love.graphics
	local cx = x + w * 0.5
	local cy = y + h * 0.5
	local r = math.min(w, h) * 0.32
	lg.setColor(color[1], color[2], color[3], 1)
	lg.circle("fill", cx, cy, r)
	local mark_color = { 0.12, 0.12, 0.12, 1 }
	if color[1] + color[2] + color[3] < 0.7 then
		mark_color = { 0.95, 0.95, 0.95, 1 }
	end
	lg.setColor(mark_color[1], mark_color[2], mark_color[3], mark_color[4])
	if draw_key == "diamond" then
		lg.polygon("line", cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy)
	elseif draw_key == "ring" then
		lg.circle("line", cx, cy, r * 0.72)
		lg.circle("fill", cx, cy, r * 0.14)
	else
		lg.circle("fill", cx, cy, r * 0.22)
	end
end

local function draw_stone_chip(stone_id, rect, stone_color, highlighted)
	local lg = love.graphics
	local stone = content.get_stone(stone_id)
	if not stone then
		return
	end
	draw_stone_graphic(stone.graphic.draw_key, rect.x, rect.y, rect.w, rect.h, stone_color)
	if not highlighted then
		return
	end
	local cx = rect.x + rect.w * 0.5
	local cy = rect.y + rect.h * 0.5
	local rr = math.min(rect.w, rect.h) * 0.43
	lg.setColor(0.96, 0.96, 0.98, 0.95)
	lg.setLineWidth(3)
	lg.circle("line", cx, cy, rr)
	lg.setLineWidth(1)
end

local function draw_score_box_simple(game, box, side, title)
	local lg = love.graphics
	local player = match_state.player_for_color(game, side)
	local turn_bonus = player.score.turn_bonus or 1
	local territory = math.ceil(player.score.territory or 0)
	local points = math.ceil(player.score.points or 0)
	local plus_mult = math.ceil(player.score.plus_mult or 1)
	local x_mult = player.score.x_mult or 1
	local total = math.ceil((turn_bonus * territory * points * plus_mult * x_mult) or 0)

	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	lg.printf(title, box.x, box.y + 8, box.w, "center")
	lg.printf(string.format("Territory: %d", territory), box.x, box.y + 30, box.w, "center")
	lg.printf(string.format("Points: %d", points), box.x, box.y + 48, box.w, "center")
	lg.printf(string.format("Mult: %d", plus_mult), box.x, box.y + 66, box.w, "center")
	lg.printf(string.format("Total: %d", total), box.x, box.y + 84, box.w, "center")
end

local function draw_score_box_detailed(game, box, side, title)
	local lg = love.graphics
	local player = match_state.player_for_color(game, side)
	local small_font = love.graphics.newFont(10)
	local prev_font = lg.getFont()

	local turn_bonus = player.score.turn_bonus or 1
	local territory = math.ceil(player.score.territory or 0)
	local points = math.ceil(player.score.points or 0)
	local plus_mult = math.ceil(player.score.plus_mult or 1)
	local x_mult = player.score.x_mult or 1
	local total = math.ceil(turn_bonus * territory * points * plus_mult * x_mult)

	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	lg.printf(title, box.x, box.y + 8, box.w, "center")

	lg.setFont(small_font)
	local y_offset = box.y + 24
	local line_height = 12

	lg.printf(string.format("Turn Bonus: %.1f", turn_bonus), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.printf(string.format("Territory: %d", territory), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.printf(string.format("Points: %d", points), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.printf(string.format("+Mult: %d", plus_mult), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.printf(string.format("×Mult: %.1f", x_mult), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.setColor(0.7, 0.7, 0.7)
	local formula = string.format("%.1f × %d × %d × %d × %.1f = %d",
		turn_bonus,
		territory,
		points,
		plus_mult,
		x_mult,
		total)
	lg.printf(formula, box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	lg.printf(string.format("Total: %d", total), box.x + 6, y_offset, box.w - 12, "left")

	lg.setFont(prev_font)
end

local function draw_score_box(game, box, side, title)
	if M._score_display_mode == "detailed" then
		draw_score_box_detailed(game, box, side, title)
	else
		draw_score_box_simple(game, box, side, title)
	end
end

local function get_stance_card_rects(box, stance_entries)
	local cards = {}
	local count = #stance_entries
	if count == 0 then
		return cards
	end
	local cols = 2
	local gap_x = 8
	local gap_y = 10
	local pad = 10
	local title_h = 28
	local card_w = math.floor((box.w - pad * 2 - gap_x) / cols)
	card_w = math.max(72, card_w)
	local card_h = math.max(82, math.floor(card_w * 1.4))
	local rows = math.ceil(count / cols)
	local usable_h = math.max(1, box.h - title_h - pad)
	local total_h = rows * card_h + math.max(0, rows - 1) * gap_y
	local step_y = card_h + gap_y
	if total_h > usable_h and rows > 1 then
		step_y = (usable_h - card_h) / (rows - 1)
		step_y = math.min(card_h + gap_y, step_y)
	end
	for i = 1, count do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		cards[i] = {
			x = box.x + pad + col * (card_w + gap_x),
			y = box.y + title_h + row * step_y,
			w = card_w,
			h = card_h,
		}
	end
	return cards
end

local function draw_stance_card_front(rect, display_name)
	local lg = love.graphics
	lg.setColor(0.96, 0.96, 0.96, 0.96)
	lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
	lg.setColor(0.2, 0.2, 0.24, 1)
	lg.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
	lg.setColor(0.12, 0.12, 0.14, 1)
	lg.printf(display_name, rect.x + 8, rect.y + 12, rect.w - 16, "center")
end

local function draw_stance_card_back(rect, display_name, description)
	local lg = love.graphics
	lg.setColor(0.97, 0.97, 0.97, 0.98)
	lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
	lg.setColor(0.2, 0.2, 0.24, 1)
	lg.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
	lg.setColor(0.12, 0.12, 0.14, 1)
	lg.printf(display_name, rect.x + 8, rect.y + 10, rect.w - 16, "center")
	lg.printf(description or "", rect.x + 10, rect.y + 34, rect.w - 20, "left")
end

local function draw_stances(box, stance_entries, owner_key)
	local lg = love.graphics
	local cards = get_stance_card_rects(box, stance_entries)
	local selected = M._stance_ui
	local selected_index = nil
	local dragging_index = nil
	if selected and selected.owner_key == owner_key then
		selected_index = selected.index
		if selected.drag_active and selected.moved then
			dragging_index = selected.drag_index
		end
	end
	for i = 1, #stance_entries do
		local entry = stance_entries[i]
		local stance_id = entry.id or entry
		local stance = content.get_stance(stance_id)
		local display_name = (stance and (stance.name or stance.display_name)) or stance_id
		if i ~= selected_index and i ~= dragging_index then
			draw_stance_card_front(cards[i], display_name)
		end
	end
	if selected_index and cards[selected_index] and selected_index ~= dragging_index then
		local entry = stance_entries[selected_index]
		local stance_id = entry.id or entry
		local stance = content.get_stance(stance_id)
		local display_name = (stance and (stance.name or stance.display_name)) or stance_id
		local focus = cards[selected_index]
		draw_stance_card_back(focus, display_name, stance and stance.description or "")
	end
	if dragging_index and cards[dragging_index] and stance_entries[dragging_index] then
		local entry = stance_entries[dragging_index]
		local stance_id = entry.id or entry
		local stance = content.get_stance(stance_id)
		local display_name = (stance and (stance.name or stance.display_name)) or stance_id
		local float_rect = {
			x = selected.current_x - math.floor(cards[dragging_index].w * 0.5),
			y = selected.current_y - math.floor(cards[dragging_index].h * 0.5),
			w = cards[dragging_index].w,
			h = cards[dragging_index].h,
		}
		if selected_index == dragging_index then
			draw_stance_card_back(float_rect, display_name, stance and stance.description or "")
		else
			draw_stance_card_front(float_rect, display_name)
		end
	end
end

--- @param rect table
--- @return nil
local function draw_popup_close_button(rect)
	local lg = love.graphics
	lg.setColor(0.4, 0.2, 0.2, 0.85)
	lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)
	lg.setColor(0.95, 0.95, 0.95, 1)
	lg.printf("Close", rect.x, rect.y + 6, rect.w, "center")
end

--- @param layout table
--- @return table
local function begin_modal_popup(layout)
	local lg = love.graphics
	local box = layout.popup
	lg.setColor(0, 0, 0, 0.45)
	lg.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
	draw_panel(box)
	local close = layout_mod.popup_close_rect(layout)
	draw_popup_close_button(close)
	return box
end

local function draw_message(game, box)
	local lg = love.graphics
	local recent = game.messages and game.messages.recent or {}
	local latest = recent[#recent]
	local anim = M._score_anim.current
	if anim then
		local timeline = M._score_anim
		local progress = 1
		if timeline.duration > 0 then
			progress = 1 - math.max(0, math.min(1, timeline.remaining / timeline.duration))
		end
		local eased = ease_out_cubic(progress)
		local alpha = 1
		if progress > 0.68 then
			alpha = 1 - ((progress - 0.68) / 0.32)
		end
		alpha = math.max(0.05, math.min(1, alpha))
		local scale = 0.88 + 0.18 * eased
		local prefix = anim.value > 0 and "+" or ""
		local label = anim.kind == "points" and "PTS" or "MULT"
		local actor = anim.actor == "black" and "BLACK" or "WHITE"
		local text = string.format("%s%d %s", prefix, anim.value, label)
		local font_prev = lg.getFont()
		if not score_anim_font then
			score_anim_font = love.graphics.newFont(42)
		end
		local big_font = score_anim_font
		lg.setFont(big_font)
		if anim.kind == "points" then
			lg.setColor(0.95, 0.86, 0.2, alpha)
		else
			lg.setColor(0.56, 0.85, 0.98, alpha)
		end
		local y = box.y + 8 + (1 - eased) * 8
		lg.push()
		lg.translate(box.x + box.w * 0.5, y + big_font:getHeight() * 0.5)
		lg.scale(scale, scale)
		lg.printf(text, -box.w * 0.5, -big_font:getHeight() * 0.5, box.w, "center")
		lg.pop()
		lg.setFont(font_prev)
		lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], alpha * 0.9)
		lg.printf(actor, box.x, box.y + box.h - 20, box.w, "center")
	elseif latest and latest ~= "" then
		local is_illegal = string.sub(latest, 1, 12) == "Illegal move"
		if is_illegal then
			lg.setColor(0.95, 0.42, 0.38, 0.98)
		else
			lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 0.95)
		end
		lg.printf(latest, box.x + 8, box.y + 18, box.w - 16, "center")
		lg.setColor(1, 1, 1, 1)
		return
	else
		return
	end
	if latest and latest ~= "" then
		local is_illegal = string.sub(latest, 1, 12) == "Illegal move"
		if is_illegal then
			lg.setColor(0.95, 0.42, 0.38, 0.98)
			lg.printf(latest, box.x + 8, box.y + box.h - 40, box.w - 16, "center")
		end
	end
	lg.setColor(1, 1, 1, 1)
end

local function draw_side_columns(game, layout)
	local lg = love.graphics
	local player = match_state.player_for_color(game, "black")
	local opp = match_state.player_for_color(game, "white")
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	draw_stances(layout.player_stances_panel, stances.all_active_stances(player, game, "A"), "A")
	draw_stances(layout.opponent_stances_panel, stances.all_active_stances(opp, game, "B"), "B")
	local stat_rects = layout_mod.player_stat_icon_rects(layout)
	draw_icon_or_fallback("energy", stat_rects[1])
	draw_icon_or_fallback("money", stat_rects[2])
	draw_icon_or_fallback("prison", stat_rects[3])
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
	lg.printf(
		string.format("%d/%d", player.resources.energy_current, player.resources.energy_max),
		stat_rects[1].x,
		stat_rects[1].y + stat_rects[1].h + 2,
		stat_rects[1].w,
		"center"
	)
	lg.printf(tostring(player.resources.money), stat_rects[2].x, stat_rects[2].y + stat_rects[2].h + 2, stat_rects[2].w, "center")
	lg.printf(tostring(player.prisoners or 0), stat_rects[3].x, stat_rects[3].y + stat_rects[3].h + 2, stat_rects[3].w, "center")
	local action_rects = layout_mod.player_action_icon_rects(layout)
	draw_icon_or_fallback("bowl", action_rects[1])
	draw_icon_or_fallback("deck", action_rects[2])
	draw_icon_or_fallback("discarded", layout_mod.discard_icon_rect(layout))
end

local function stone_color_for_side(side)
	if side == "black" then
		return config.COLOR_BLACK_STONE
	end
	return config.COLOR_WHITE_STONE
end

local function draw_selector(game, layout, popup_state)
	local player = match_state.player_for_color(game, "black")
	local dragged_index = nil
	local dragging = M._stone_drag
	if dragging and dragging.active and dragging.moved then
		dragged_index = dragging.source_index
	end
	local visible_stones = {}
	local visible_to_real = {}
	for i = 1, #player.stones.playable_stones do
		if i ~= dragged_index then
			visible_stones[#visible_stones + 1] = player.stones.playable_stones[i]
			visible_to_real[#visible_to_real + 1] = i
		end
	end
	local rects = layout_mod.stone_chip_rects(layout, #visible_stones)
	local selected_slot = popup_state and popup_state.selected_slot or nil
	if (not selected_slot) and player.stones.selected_stone_index then
		selected_slot = player.stones.selected_stone_index
	end
	if selected_slot and (selected_slot < 1 or selected_slot > #player.stones.playable_stones) then
		selected_slot = nil
	end
	if (not selected_slot) and player.stones.selected_stone then
		for i = 1, #player.stones.playable_stones do
			if player.stones.playable_stones[i] == player.stones.selected_stone then
				selected_slot = i
				break
			end
		end
	end
	for i = 1, #rects do
		local rect = rects[i]
		local stone_id = visible_stones[i]
		local highlighted = selected_slot and visible_to_real[i] == selected_slot or false
		draw_stone_chip(stone_id, rect, stone_color_for_side("black"), highlighted)
	end
end

local function draw_hand(game, layout)
	local lg = love.graphics
	local player = match_state.player_for_color(game, "black")
	local hand = player.cards.hand.ids
	local selected = (M._card_ui and M._card_ui.selected_index) or nil
	local dragging_index = nil
	if M._card_ui and M._card_ui.drag_active and M._card_ui.moved then
		dragging_index = M._card_ui.drag_index
	end
	local slots = layout_mod.hand_fan_slots(layout, #hand)
	local function draw_card(slot, card_id, full_front)
		local card = content.get_card(card_id)
		if not card then
			return
		end
		local can_afford = player.resources.energy_current >= card.energy_cost
		lg.push()
		local cx = slot.x + slot.w * 0.5
		local cy = slot.y + slot.h * 0.5
		lg.translate(cx, cy)
		lg.rotate(slot.angle)
		if can_afford then
			lg.setColor(0.36, 0.54, 0.74, 0.92)
		else
			lg.setColor(0.44, 0.3, 0.26, 0.88)
		end
		lg.rectangle("fill", -slot.w * 0.5, -slot.h * 0.5, slot.w, slot.h, 8, 8)
		lg.setColor(config.COLOR_GRID[1], config.COLOR_GRID[2], config.COLOR_GRID[3], 1)
		lg.rectangle("line", -slot.w * 0.5, -slot.h * 0.5, slot.w, slot.h, 8, 8)
		lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
		lg.printf(tostring(card.energy_cost), -slot.w * 0.5 + 8, -slot.h * 0.5 + 8, 18, "center")
		lg.printf(card.name or card.display_name, -slot.w * 0.5 + 32, -slot.h * 0.5 + 12, slot.w - 42, "left")
		if full_front then
			local desc = card.description or ""
			lg.printf(desc, -slot.w * 0.5 + 10, -slot.h * 0.5 + 40, slot.w - 20, "left")
		end
		lg.pop()
	end
	for i = 1, #slots do
		if i ~= selected and i ~= dragging_index then
			draw_card(slots[i], hand[i], false)
		end
	end
	if selected and slots[selected] and hand[selected] and selected ~= dragging_index then
		local slot = slots[selected]
		local focus = {
			x = slot.x,
			y = layout.hand_panel.y + 8,
			w = slot.w,
			h = math.min(slot.h, layout.hand_panel.h - 16),
			angle = 0,
		}
		draw_card(focus, hand[selected], true)
		local use_button = layout_mod.card_use_button_rect(layout)
		lg.setColor(0.26, 0.56, 0.32, 0.92)
		lg.rectangle("fill", use_button.x, use_button.y, use_button.w, use_button.h, 6, 6)
		lg.setColor(config.COLOR_GRID[1], config.COLOR_GRID[2], config.COLOR_GRID[3], 1)
		lg.rectangle("line", use_button.x, use_button.y, use_button.w, use_button.h, 6, 6)
		lg.setColor(0.96, 0.96, 0.96, 1)
		lg.printf("Use", use_button.x, use_button.y + 10, use_button.w, "center")
	end
	if dragging_index and hand[dragging_index] then
		local drag = M._card_ui
		local slot = slots[dragging_index] or {
			x = layout.hand_panel.x + 16,
			y = layout.hand_panel.y + 16,
			w = 120,
			h = 170,
			angle = 0,
		}
		local floating = {
			x = drag.current_x - math.floor(slot.w * 0.5),
			y = drag.current_y - math.floor(slot.h * 0.5),
			w = slot.w,
			h = slot.h,
			angle = 0,
		}
		draw_card(floating, hand[dragging_index], true)
		local use_button = layout_mod.card_use_button_rect(layout)
		lg.setColor(0.26, 0.56, 0.32, 0.92)
		lg.rectangle("fill", use_button.x, use_button.y, use_button.w, use_button.h, 6, 6)
		lg.setColor(config.COLOR_GRID[1], config.COLOR_GRID[2], config.COLOR_GRID[3], 1)
		lg.rectangle("line", use_button.x, use_button.y, use_button.w, use_button.h, 6, 6)
		lg.setColor(0.96, 0.96, 0.96, 1)
		lg.printf("Use", use_button.x, use_button.y + 10, use_button.w, "center")
	end
end

local function draw_board(game, layout, hover_row, hover_col, show_hover, popup_state)
	local lg = love.graphics
	draw_panel(layout.board)
	local territory = game.territory
	local n = layout.board_metrics.n
	if territory then
		lg.setScissor(layout.board_metrics.x, layout.board_metrics.y, layout.board_metrics.w, layout.board_metrics.h)
		local half = layout.board_metrics.cell * 0.5
		for r = 1, n do
			for c = 1, n do
				local cell = game.board[r][c]
				if cells.is_empty(cell) then
					local owner = territory[r] and territory[r][c] or config.STONE_NONE
					if owner == config.STONE_BLACK or owner == config.STONE_WHITE then
						local px, py = layout_mod.grid_to_pixel(layout, r, c)
						if owner == config.STONE_BLACK then
							lg.setColor(0.18, 0.28, 0.46, 0.26)
						else
							lg.setColor(0.92, 0.92, 0.94, 0.28)
						end
						lg.rectangle("fill", px - half, py - half, half * 2, half * 2)
					end
				end
			end
		end
		lg.setScissor()
	end
	lg.setColor(config.COLOR_GRID[1], config.COLOR_GRID[2], config.COLOR_GRID[3])
	lg.setLineWidth(config.GRID_LINE_WIDTH)
	for i = 1, n do
		local x1, y1 = layout_mod.grid_to_pixel(layout, i, 1)
		local x2, y2 = layout_mod.grid_to_pixel(layout, i, n)
		lg.line(x1, y1, x2, y2)
		local xa, ya = layout_mod.grid_to_pixel(layout, 1, i)
		local xb, yb = layout_mod.grid_to_pixel(layout, n, i)
		lg.line(xa, ya, xb, yb)
	end
	local rad = layout.board_metrics.cell * config.STONE_RADIUS_FACTOR
	for r = 1, n do
		for c = 1, n do
			local cell = game.board[r][c]
			if not cells.is_empty(cell) then
				local px, py = layout_mod.grid_to_pixel(layout, r, c)
				local color = cell.color == config.STONE_BLACK and config.COLOR_BLACK_STONE or config.COLOR_WHITE_STONE
				draw_stone_chip(cell.kind, { x = px - rad, y = py - rad, w = rad * 2, h = rad * 2 }, color, false)
			end
		end
	end
	local selected_target = game.selected_card_target
	if selected_target and selected_target.row and selected_target.col then
		local px, py = layout_mod.grid_to_pixel(layout, selected_target.row, selected_target.col)
		lg.setColor(0.96, 0.84, 0.22, 0.95)
		lg.setLineWidth(3)
		lg.circle("line", px, py, rad * 0.92)
		lg.setLineWidth(1)
	end
	local probe = M._influence_probe
	if probe and probe.contributors then
		local marked = {}
		local owners = { "A", "B" }
		if probe.owner == "A" then
			owners = { "A" }
		elseif probe.owner == "B" then
			owners = { "B" }
		end
		for oi = 1, #owners do
			local owner = owners[oi]
			local list = probe.contributors[owner] or {}
			for i = 1, #list do
				local sr, sc = list[i].r, list[i].c
				local key = sr * 100 + sc
				if not marked[key] then
					marked[key] = true
					local px, py = layout_mod.grid_to_pixel(layout, sr, sc)
					lg.setColor(0.96, 0.96, 0.96, 0.95)
					lg.setLineWidth(3)
					lg.circle("line", px, py, rad * 1.22)
				end
			end
		end
		lg.setLineWidth(1)
	end
	if hover_row and hover_col and show_hover then
		local px, py = layout_mod.grid_to_pixel(layout, hover_row, hover_col)
		lg.setColor(config.COLOR_HIGHLIGHT[1], config.COLOR_HIGHLIGHT[2], config.COLOR_HIGHLIGHT[3], config.COLOR_HIGHLIGHT[4])
		lg.circle("fill", px, py, layout.board_metrics.cell * 0.2)
	end
end

local function board_stone_info_rect(layout, popup_state)
	local px, py = layout_mod.grid_to_pixel(layout, popup_state.row, popup_state.col)
	local box_w = 250
	local box_h = 96
	local offset = 18
	local x = px + offset
	local y = py - math.floor(box_h * 0.5)
	if x + box_w > layout.board.x + layout.board.w then
		x = px - offset - box_w
	end
	if y < layout.board.y then
		y = layout.board.y + 4
	end
	if y + box_h > layout.board.y + layout.board.h then
		y = layout.board.y + layout.board.h - box_h - 4
	end
	return { x = x, y = y, w = box_w, h = box_h }
end

local function draw_board_stone_popup(layout, popup_state)
	local stone = content.get_stone(popup_state.stone_id)
	if not stone then
		return
	end
	local lg = love.graphics
	local box = board_stone_info_rect(layout, popup_state)
	draw_panel(box)
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
	lg.printf(stone.name or popup_state.stone_id, box.x + 10, box.y + 10, box.w - 20, "left")
	lg.printf(stone.description or "", box.x + 10, box.y + 34, box.w - 20, "left")
	local key = popup_state.row .. ":" .. popup_state.col
	local mods = popup_state.game_state and popup_state.game_state.board_stone_modifiers and popup_state.game_state.board_stone_modifiers[key]
	local points_bonus = mods and mods.points_bonus or 0
	lg.printf("Bonus: " .. tostring(points_bonus), box.x + 10, box.y + box.h - 22, box.w - 20, "left")
	lg.printf("Selected target", box.x + 10, box.y + box.h - 22, box.w - 20, "right")
end

--- @param layout table
--- @param popup_state table
--- @return nil
local function draw_selector_details_popup(layout, popup_state)
	local stone = content.get_stone(popup_state.stone_id)
	if not stone then
		return
	end
	local anchor = popup_state.anchor_rect
	if not anchor then
		return
	end
	local lg = love.graphics
	local tooltip = {
		x = anchor.x + anchor.w + 8,
		y = anchor.y - 6,
		w = 240,
		h = 86,
	}
	draw_panel(tooltip)
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
	lg.printf(stone.name, tooltip.x + 10, tooltip.y + 10, tooltip.w - 20, "left")
	lg.printf(stone.description, tooltip.x + 10, tooltip.y + 34, tooltip.w - 20, "left")
end

--- @param layout table
--- @param popup_state table
--- @return nil
local function draw_pouch_browser_popup(layout, popup_state)
	local lg = love.graphics
	local box = begin_modal_popup(layout)
	lg.printf("Pouch Browser", box.x + 20, box.y + 18, box.w - 140, "left")
	local rects = layout_mod.pouch_popup_grid_rects(layout, #popup_state.stones)
	for i = 1, #rects do
		draw_stone_chip(popup_state.stones[i], rects[i], stone_color_for_side("black"), popup_state.focus_index == i)
	end
	if not popup_state.focus_index then
		return
	end
	local stone = content.get_stone(popup_state.stones[popup_state.focus_index])
	if not stone then
		return
	end
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
	lg.printf(stone.name, box.x + 20, box.y + box.h - 86, box.w - 40, "left")
	lg.printf(stone.description, box.x + 20, box.y + box.h - 58, box.w - 40, "left")
end

--- @param card_id string
--- @param rect table
--- @param highlighted boolean
--- @return nil
local function draw_popup_card_tile(card_id, rect, highlighted)
	local lg = love.graphics
	local card = content.get_card(card_id)
	if not card then
		return
	end
	if highlighted then
		lg.setColor(0.26, 0.54, 0.78, 0.86)
	else
		lg.setColor(0.32, 0.47, 0.66, 0.78)
	end
	lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
	lg.setColor(config.COLOR_GRID[1], config.COLOR_GRID[2], config.COLOR_GRID[3], 1)
	lg.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
	lg.printf(tostring(card.energy_cost), rect.x + 6, rect.y + 6, 16, "center")
	lg.printf(card.name or card.display_name, rect.x + 26, rect.y + 10, rect.w - 32, "left")
end

--- @param box table
--- @param cards table
--- @param focus_group string|nil
--- @param focus_index integer|nil
--- @return nil
local function draw_played_cards_grid(box, cards, focus_group, focus_index)
	local cols = 5
	local gap = 8
	local pad = 16
	local chip = math.floor((box.w - pad * 2 - gap * (cols - 1)) / cols)
	chip = math.max(56, math.min(78, chip))
	local played_offset_y = box.y + 52 + 160
	for i = 1, #cards do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local rect = {
			x = box.x + pad + col * (chip + gap),
			y = played_offset_y + row * (chip + gap),
			w = chip,
			h = chip,
		}
		draw_popup_card_tile(cards[i], rect, focus_group == "played" and focus_index == i)
	end
end

--- @param layout table
--- @param popup_state table
--- @return nil
local function draw_deck_browser_popup(layout, popup_state)
	local lg = love.graphics
	local box = begin_modal_popup(layout)
	local title = popup_state.mode == "discard-browser" and "Discard Browser" or "Deck Browser"
	lg.printf(title, box.x + 20, box.y + 18, box.w - 140, "left")
	local deck_cards = popup_state.cards or {}
	local played_cards = popup_state.played_cards or {}
	local y_top = box.y + 52
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
	if popup_state.mode ~= "discard-browser" then
		lg.printf("Deck", box.x + 20, y_top - 20, box.w - 40, "left")
	end
	local deck_rects = layout_mod.pouch_popup_grid_rects(layout, #deck_cards)
	for i = 1, #deck_rects do
		draw_popup_card_tile(deck_cards[i], deck_rects[i], popup_state.focus_group == "deck" and popup_state.focus_index == i)
	end
	local played_label = popup_state.mode == "discard-browser" and "Discarded" or "Played"
	lg.printf(played_label, box.x + 20, y_top + 140, box.w - 40, "left")
	draw_played_cards_grid(box, played_cards, popup_state.focus_group, popup_state.focus_index)
	if not popup_state.focus_group or not popup_state.focus_index then
		return
	end
	local source = popup_state.focus_group == "played" and played_cards or deck_cards
	local card = content.get_card(source[popup_state.focus_index])
	if not card then
		return
	end
	lg.printf(card.name or card.display_name, box.x + 20, box.y + box.h - 86, box.w - 40, "left")
	lg.printf(card.description or "", box.x + 20, box.y + box.h - 58, box.w - 40, "left")
end

local function draw_popup(layout, popup_state)
	if not popup_state or popup_state.mode == "none" then
		return
	end
	if popup_state.mode == "selector-details" and popup_state.stone_id then
		draw_selector_details_popup(layout, popup_state)
	elseif popup_state.mode == "pouch-browser" then
		draw_pouch_browser_popup(layout, popup_state)
	elseif popup_state.mode == "deck-browser" then
		draw_deck_browser_popup(layout, popup_state)
	elseif popup_state.mode == "discard-browser" then
		draw_deck_browser_popup(layout, popup_state)
	elseif popup_state.mode == "board-stone-info" then
		draw_board_stone_popup(layout, popup_state)
	end
end

function M.popup_hit_test(layout, popup_state, x, y)
	if not popup_state or popup_state.mode == "none" then
		return { kind = "none" }
	end
	if popup_state.mode == "selector-details" then
		return { kind = "none" }
	end
	local close = layout_mod.popup_close_rect(layout)
	if popup_state.mode == "board-stone-info" then
		local box = board_stone_info_rect(layout, popup_state)
		if inside(box, x, y) then
			return { kind = "consume" }
		end
		return { kind = "none" }
	end
	if inside(close, x, y) then
		return { kind = "close" }
	end
	if popup_state.mode == "pouch-browser" then
		local rects = layout_mod.pouch_popup_grid_rects(layout, #popup_state.stones)
		for i = 1, #rects do
			if inside(rects[i], x, y) then
				return { kind = "pouch_stone", index = i }
			end
		end
	end
	if popup_state.mode == "deck-browser" or popup_state.mode == "discard-browser" then
		local box = layout.popup
		local deck_cards = popup_state.cards or {}
		local deck_rects = layout_mod.pouch_popup_grid_rects(layout, #deck_cards)
		for i = 1, #deck_rects do
			if inside(deck_rects[i], x, y) then
				return { kind = "deck_card", group = "deck", index = i }
			end
		end
		local played_cards = popup_state.played_cards or {}
		local cols = 5
		local gap = 8
		local pad = 16
		local chip = math.floor((box.w - pad * 2 - gap * (cols - 1)) / cols)
		chip = math.max(56, math.min(78, chip))
		local played_offset_y = box.y + 52 + 160
		for i = 1, #played_cards do
			local col = (i - 1) % cols
			local row = math.floor((i - 1) / cols)
			local rect = {
				x = box.x + pad + col * (chip + gap),
				y = played_offset_y + row * (chip + gap),
				w = chip,
				h = chip,
			}
			if inside(rect, x, y) then
				return { kind = "deck_card", group = "played", index = i }
			end
		end
	end
	return { kind = "consume" }
end

function M.draw(game, layout, hover_row, hover_col, show_hover, popup_state, stone_drag)
	local lg = love.graphics
	draw_game_background()
	draw_message(game, layout.message_panel)
	draw_panel(layout.score_player)
	draw_panel(layout.score_opponent)
	draw_score_box(game, layout.score_player, "black", "Player Score")
	draw_score_box(game, layout.score_opponent, "white", "Opponent Score")
	draw_side_columns(game, layout)
	draw_selector(game, layout, popup_state)
	draw_hand(game, layout)
	draw_board(game, layout, hover_row, hover_col, show_hover, popup_state)
	draw_popup(layout, popup_state)
	if stone_drag and stone_drag.active and stone_drag.moved and stone_drag.stone_id then
		draw_stone_chip(
			stone_drag.stone_id,
			{ x = stone_drag.current_x - 28, y = stone_drag.current_y - 28, w = 56, h = 56 },
			stone_color_for_side("black"),
			false
		)
	end
	local draw_anim = M._stone_draw_anim
	if draw_anim.current and draw_anim.current.actor == "black" then
		local event = draw_anim.current
		local start_rect = layout_mod.player_action_icon_rects(layout)[1]
		local end_rects = layout_mod.stone_chip_rects(layout, #match_state.player_for_color(game, "black").stones.playable_stones)
		local target = end_rects[event.target_index]
		if start_rect and target then
			local t = 0
			if draw_anim.duration > 0 then
				t = math.max(0, math.min(1, draw_anim.elapsed / draw_anim.duration))
			end
			local sx = start_rect.x + start_rect.w * 0.5
			local sy = start_rect.y + start_rect.h * 0.5
			local tx = target.x + target.w * 0.5
			local ty = target.y + target.h * 0.5
			local x = sx + (tx - sx) * t
			local y = sy + (ty - sy) * t
			draw_stone_chip(event.stone_id, { x = x - 24, y = y - 24, w = 48, h = 48 }, stone_color_for_side("black"), false)
		end
	end
	lg.setColor(1, 1, 1, 1)
end

function M.update(dt, game)
	local anim = M._score_anim
	local draw_anim = M._stone_draw_anim
	local events = game.messages.score_events or {}
	for i = 1, #events do
		anim.queue[#anim.queue + 1] = events[i]
	end
	game.messages.score_events = {}
	local draw_events = game.stone_draw_events or {}
	for i = 1, #draw_events do
		draw_anim.queue[#draw_anim.queue + 1] = draw_events[i]
	end
	game.stone_draw_events = {}
	if draw_anim.current then
		draw_anim.elapsed = draw_anim.elapsed + dt
		if draw_anim.elapsed >= draw_anim.duration then
			draw_anim.current = nil
			draw_anim.elapsed = 0
		end
	end
	if (not draw_anim.current) and #draw_anim.queue > 0 then
		draw_anim.current = table.remove(draw_anim.queue, 1)
		draw_anim.elapsed = 0
	end
	if anim.current then
		anim.remaining = anim.remaining - dt
		if anim.remaining > 0 then
			return
		end
		anim.current = nil
	end
	if #anim.queue == 0 then
		return
	end
	anim.current = table.remove(anim.queue, 1)
	local speed = game.animation_speed or 1
	anim.duration = SCORE_ANIM_BASE_DURATION * speed
	anim.remaining = anim.duration
end

function M.is_score_animating()
	local anim = M._score_anim
	return anim.current ~= nil or #anim.queue > 0
end

function M.set_card_ui_state(card_ui_state)
	M._card_ui = card_ui_state
end

function M.set_stance_ui_state(stance_ui_state)
	M._stance_ui = stance_ui_state
end

function M.set_stone_drag_state(stone_drag_state)
	M._stone_drag = stone_drag_state
end

function M.set_influence_probe_state(influence_probe_state)
	M._influence_probe = influence_probe_state
end

function M.stance_hit_test(game, layout, x, y)
	local player = match_state.player_for_color(game, "black")
	local opp = match_state.player_for_color(game, "white")
	local panels = {
		{ owner_key = "A", box = layout.player_stances_panel, entries = stances.all_active_stances(player, game, "A") },
		{ owner_key = "B", box = layout.opponent_stances_panel, entries = stances.all_active_stances(opp, game, "B") },
	}
	for p = 1, #panels do
		local panel = panels[p]
		local rects = get_stance_card_rects(panel.box, panel.entries)
		for i = #rects, 1, -1 do
			if inside(rects[i], x, y) then
				return { kind = "stance_card", owner_key = panel.owner_key, index = i }
			end
		end
		if inside(panel.box, x, y) then
			return { kind = "stance_panel", owner_key = panel.owner_key }
		end
	end
	return { kind = "none" }
end

function M.toggle_score_display_mode()
	if M._score_display_mode == "simple" then
		M._score_display_mode = "detailed"
	else
		M._score_display_mode = "simple"
	end
end

function M.get_score_display_mode()
	return M._score_display_mode
end

return M
