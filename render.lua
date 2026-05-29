local cells = require("board")
local config = require("config")
local content = require("content")
local layout_mod = require("layout")
local match_state = require("match_state")
local messages = require("messages")
local stances = require("stances")
local pouch = require("pouch")
local ui_fonts = require("ui.fonts")
local card_geometry = require("ui.card_geometry")
local card_layout = require("ui.card_layout")
local card_visual = require("ui.card_visual")
local sprites = require("ui.sprites")
local stone_solidity = require("objects.stone_solidity")
local stone_solidity_atlas = require("ui.stone_solidity_atlas")
local stance_card_draw = require("ui.stance_card_draw")
local stance_detail_popup = require("ui.stance_detail_popup")
local ui_animations = require("ui.animations")
local score_display = require("ui.score_display")
local number_format = require("ui.number_format")
local resolver = require("resolver")

local M = {}
local SCORE_ANIM_BASE_DURATION = 0.45
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
	ui_fonts.set("body_small")
	lg.printf(name, rect.x + 4, rect.y + math.floor(rect.h * 0.35), rect.w - 8, "center")
	ui_fonts.apply_default()
end

--- Draws full-screen board background image if available.
--- Falls back to solid board color when sprite is missing.
--- @return nil
local function draw_game_background()
	local lg = love.graphics
	local bg = get_ui_sprite("background_3")
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

local function draw_card_target_arrow(from_x, from_y, to_x, to_y, is_valid)
	local lg = love.graphics
	local dx = to_x - from_x
	local dy = to_y - from_y
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1 then
		return
	end
	local ux = dx / len
	local uy = dy / len
	local perp_x = -uy
	local perp_y = ux
	local curve_bend = math.min(72, math.max(18, len * 0.18))
	local cx = (from_x + to_x) * 0.5 + perp_x * curve_bend
	local cy = (from_y + to_y) * 0.5 + perp_y * curve_bend
	local segments = 20
	local points = {}
	for i = 0, segments do
		local t = i / segments
		local omt = 1 - t
		local px = omt * omt * from_x + 2 * omt * t * cx + t * t * to_x
		local py = omt * omt * from_y + 2 * omt * t * cy + t * t * to_y
		points[#points + 1] = px
		points[#points + 1] = py
	end
	local tangent_x = to_x - cx
	local tangent_y = to_y - cy
	local tangent_len = math.sqrt(tangent_x * tangent_x + tangent_y * tangent_y)
	if tangent_len < 0.001 then
		tangent_x = ux
		tangent_y = uy
		tangent_len = 1
	end
	local tx = tangent_x / tangent_len
	local ty = tangent_y / tangent_len
	local nx = -ty
	local ny = tx
	if is_valid then
		lg.setColor(0.16, 0.16, 0.18, 0.4)
		lg.setLineWidth(8)
		lg.line(points)
		lg.setColor(0.95, 0.84, 0.22, 0.96)
		lg.setLineWidth(5)
		lg.line(points)
	else
		lg.setColor(0.14, 0.14, 0.16, 0.35)
		lg.setLineWidth(8)
		lg.line(points)
		lg.setColor(0.55, 0.55, 0.57, 0.9)
		lg.setLineWidth(5)
		lg.line(points)
	end
	local head = math.min(20, math.max(12, len * 0.09))
	local wing = head * 0.52
	local bx = to_x - tx * head
	local by = to_y - ty * head
	lg.setColor(0.16, 0.16, 0.18, 0.45)
	lg.polygon("fill", to_x, to_y, bx + nx * (wing + 2), by + ny * (wing + 2), bx - nx * (wing + 2), by - ny * (wing + 2))
	if is_valid then
		lg.setColor(0.95, 0.84, 0.22, 0.96)
	else
		lg.setColor(0.55, 0.55, 0.57, 0.9)
	end
	lg.polygon("fill", to_x, to_y, bx + nx * wing, by + ny * wing, bx - nx * wing, by - ny * wing)
	lg.setLineWidth(1)
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

--- @param rect table
--- @param scale number
--- @return table
local function centered_sub_rect(rect, scale)
	local w = rect.w * scale
	local h = rect.h * scale
	return {
		x = rect.x + (rect.w - w) * 0.5,
		y = rect.y + (rect.h - h) * 0.5,
		w = w,
		h = h,
	}
end

--- Type tint + sprite or graphic (centered overlay; no owner ring).
--- @param stone_id string
--- @param rect table
--- @return nil
local function draw_stone_type_overlay(stone_id, rect)
	local lg = love.graphics
	local stone = content.get_stone(stone_id)
	if not stone then
		return
	end
	local cx = rect.x + rect.w * 0.5
	local cy = rect.y + rect.h * 0.5
	local tint = { 0.7, 0.7, 0.72 }
	local sprite_path = nil
	if stone.visual then
		if type(stone.visual.color) == "table" and stone.visual.color[1] then
			tint = stone.visual.color
		end
		sprite_path = stone.visual.sprite
	end
	local img = sprite_path and sprites.get_image(sprite_path)
	local rr = math.min(rect.w, rect.h) * 0.42
	if img and img ~= false then
		lg.setColor(tint[1], tint[2], tint[3], 1)
		lg.circle("fill", cx, cy, rr * 0.92)
		lg.setColor(1, 1, 1, 1)
		lg.draw(img, rect.x, rect.y, 0, rect.w / img:getWidth(), rect.h / img:getHeight())
	else
		local fill = { tint[1], tint[2], tint[3] }
		draw_stone_graphic(stone.graphic and stone.graphic.draw_key or "solid", rect.x, rect.y, rect.w, rect.h, fill)
	end
end

--- @param atlas_img love.graphics.Image
--- @param atlas_quad love.graphics.Quad
--- @param rect table
--- @return boolean drew without error
local function try_draw_solidity_base(atlas_img, atlas_quad, rect)
	local lg = love.graphics
	local ok = pcall(function()
		lg.setColor(1, 1, 1, 1)
		local _, _, qw, qh = atlas_quad:getViewport()
		local scale_x = rect.w / math.max(1, qw)
		local scale_y = rect.h / math.max(1, qh)
		lg.draw(atlas_img, atlas_quad, rect.x, rect.y, 0, scale_x, scale_y)
	end)
	if not ok then
		lg.setColor(1, 1, 1, 1)
	end
	return ok
end

--- @param stone_id string
--- @param rect table
--- @param owner_side string  ``"black"`` | ``"white"`` — atlas row (deterioration art).
--- @param highlighted boolean
--- @param solidity integer|nil current health; nil = max for ``stone_id``
--- @return nil
local function draw_stone_chip(stone_id, rect, owner_side, highlighted, solidity)
	local lg = love.graphics
	local stone = content.get_stone(stone_id)
	if not stone then
		return
	end
	local tier = M.stone_visual_tier(stone_id, solidity)
	local atlas_img, atlas_quad = stone_solidity_atlas.get_frame(owner_side, tier)
	local drew_atlas = atlas_img and atlas_quad and try_draw_solidity_base(atlas_img, atlas_quad, rect)
	if drew_atlas then
		draw_stone_type_overlay(stone_id, centered_sub_rect(rect, 0.55))
	else
		draw_stone_type_overlay(stone_id, rect)
	end
	if not highlighted then
		return
	end
	local cx = rect.x + rect.w * 0.5
	local cy = rect.y + rect.h * 0.5
	local rr = math.min(rect.w, rect.h) * 0.42
	lg.setColor(0.55, 0.82, 0.96, 0.95)
	lg.setLineWidth(2)
	lg.circle("line", cx, cy, rr + 3)
	lg.setLineWidth(1)
	lg.setColor(1, 1, 1, 1)
end

--- @param stone_id string
--- @param solidity integer|nil
--- @return integer
function M.stone_visual_tier(stone_id, solidity)
	local current = stone_solidity.resolve_solidity(stone_id, solidity)
	local max_s = stone_solidity.stone_max_solidity(stone_id)
	return stone_solidity.solidity_tier(current, max_s)
end

local function draw_score_box_simple(game, box, side, title)
	local lg = love.graphics
	local row = score_display.effective_row(game, side)
	local turn_bonus = row.turn_bonus or 1
	local territory = math.ceil(row.territory or 0)
	local points = math.ceil(row.points or 0)
	local plus_mult = math.ceil(row.plus_mult or 1)
	local x_mult = row.x_mult or 1
	local overall_mult = plus_mult * x_mult
	local total = score_display.calculate_display_total(row)

	ui_fonts.set("body")
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	lg.printf(title, box.x, box.y + 8, box.w, "center")
	lg.printf("Territory: " .. number_format.format_integer(territory), box.x, box.y + 30, box.w, "center")
	lg.printf("Points: " .. number_format.format_integer(points), box.x, box.y + 48, box.w, "center")
	lg.printf("Mult: " .. number_format.format_decimal(overall_mult, 1), box.x, box.y + 66, box.w, "center")
	lg.printf("Total: " .. number_format.format_integer(total), box.x, box.y + 84, box.w, "center")
	ui_fonts.apply_default()
end

local function draw_score_box_detailed(game, box, side, title)
	local lg = love.graphics
	local row = score_display.effective_row(game, side)

	local turn_bonus = row.turn_bonus or 1
	local territory = math.ceil(row.territory or 0)
	local points = math.ceil(row.points or 0)
	local plus_mult = math.ceil(row.plus_mult or 1)
	local x_mult = row.x_mult or 1
	local total = score_display.calculate_display_total(row)

	ui_fonts.set("body")
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	lg.printf(title, box.x, box.y + 8, box.w, "center")

	ui_fonts.set("body_small")
	local y_offset = box.y + 24
	local line_height = 12

	lg.printf("Turn Bonus: " .. number_format.format_decimal(turn_bonus, 1), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.printf("Territory: " .. number_format.format_integer(territory), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.printf("Points: " .. number_format.format_integer(points), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.printf("+Mult: " .. number_format.format_integer(plus_mult), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.printf("×Mult: " .. number_format.format_decimal(x_mult, 1), box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.setColor(0.7, 0.7, 0.7)
	local formula = table.concat({
		number_format.format_decimal(turn_bonus, 1),
		number_format.format_integer(territory),
		number_format.format_integer(points),
		number_format.format_integer(plus_mult),
		number_format.format_decimal(x_mult, 1),
	}, " × ")
	formula = formula .. " = " .. number_format.format_integer(total)
	lg.printf(formula, box.x + 6, y_offset, box.w - 12, "left")
	y_offset = y_offset + line_height

	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	lg.printf("Total: " .. number_format.format_integer(total), box.x + 6, y_offset, box.w - 12, "left")

	ui_fonts.apply_default()
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
	local card_h = math.ceil(card_geometry.height_for_width(card_w))
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

local function draw_stance_tile(rect, stance)
	stance_card_draw.draw_portrait(rect, stance)
	stance_card_draw.draw_frame(rect, stance)
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
		if i ~= selected_index and i ~= dragging_index then
			if not ui_animations.stance_shake_replaces_slot(owner_key, i) then
				draw_stance_tile(cards[i], stance)
			end
		end
	end
	if selected_index and cards[selected_index] and selected_index ~= dragging_index then
		local entry = stance_entries[selected_index]
		local stance_id = entry.id or entry
		local stance = content.get_stance(stance_id)
		local focus = cards[selected_index]
		if not ui_animations.stance_shake_replaces_slot(owner_key, selected_index) then
			draw_stance_tile(focus, stance)
		end
	end
	if dragging_index and cards[dragging_index] and stance_entries[dragging_index] then
		local entry = stance_entries[dragging_index]
		local stance_id = entry.id or entry
		local stance = content.get_stance(stance_id)
		local float_rect = {
			x = selected.current_x - math.floor(cards[dragging_index].w * 0.5),
			y = selected.current_y - math.floor(cards[dragging_index].h * 0.5),
			w = cards[dragging_index].w,
			h = cards[dragging_index].h,
		}
		draw_stance_tile(float_rect, stance)
	end
end

local function stance_panel_for_owner(game, layout, owner_key)
	local player = match_state.player_for_color(game, "black")
	local opp = match_state.player_for_color(game, "white")
	if owner_key == config.OWNER_BLACK then
		return layout.player_stances_panel, stances.all_active_stances(player, game, config.OWNER_BLACK)
	end
	return layout.opponent_stances_panel, stances.all_active_stances(opp, game, config.OWNER_WHITE)
end

function M.get_stance_detail_popup_rect(game, layout, stance_ui_state)
	if not stance_ui_state or not stance_ui_state.index or not stance_ui_state.owner_key then
		return nil
	end
	if stance_ui_state.drag_active and stance_ui_state.moved then
		return nil
	end
	local panel, entries = stance_panel_for_owner(game, layout, stance_ui_state.owner_key)
	local cards = get_stance_card_rects(panel, entries)
	local index = stance_ui_state.index
	local anchor = cards[index]
	if not anchor then
		return nil
	end
	local entry = entries[index]
	if not entry then
		return nil
	end
	local stance_id = entry.id or entry
	local stance = content.get_stance(stance_id)
	if not stance then
		return nil
	end
	return stance_detail_popup.layout_for_def(
		anchor,
		stance,
		game,
		stance_ui_state.owner_key,
		love.graphics.getWidth(),
		love.graphics.getHeight()
	)
end

local function draw_stance_detail_popup(game, layout)
	local stance_ui_state = M._stance_ui
	local box = M.get_stance_detail_popup_rect(game, layout, stance_ui_state)
	if box then
		stance_detail_popup.draw(box)
	end
end

--- @param rect table
--- @return nil
local function draw_popup_close_button(rect)
	local lg = love.graphics
	lg.setColor(0.4, 0.2, 0.2, 0.85)
	lg.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 4, 4)
	lg.setColor(0.95, 0.95, 0.95, 1)
	ui_fonts.set("body_small")
	lg.printf("Close", rect.x, rect.y + 6, rect.w, "center")
	ui_fonts.apply_default()
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
	ui_fonts.set("body")
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
		local big_font = ui_fonts.get("large")
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
		ui_fonts.set("body")
		lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], alpha * 0.9)
		lg.printf(actor, box.x, box.y + box.h - 20, box.w, "center")
	elseif latest and latest ~= "" then
		ui_fonts.set("body")
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
		ui_fonts.set("body")
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
	ui_fonts.set("body")
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	draw_stances(layout.player_stances_panel, stances.all_active_stances(player, game, config.OWNER_BLACK), config.OWNER_BLACK)
	draw_stances(layout.opponent_stances_panel, stances.all_active_stances(opp, game, config.OWNER_WHITE), config.OWNER_WHITE)
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

local function owner_side_from_stone_color(color)
	if color == config.STONE_BLACK then
		return "black"
	end
	return "white"
end

local function draw_selector(game, layout, popup_state)
	local active_side = game.to_play
	local player = match_state.player_for_color(game, active_side)
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
		draw_stone_chip(stone_id, rect, active_side, highlighted)
	end
end

local function draw_energy_badge(lg, x0, y0, regions, cost, circle_color)
	local r = regions.energy_r
	local cx = x0 + regions.energy_cx
	local cy = y0 + regions.energy_cy
	local cr, cg, cb, _ = card_visual.rgba_from_hex(circle_color)
	lg.setColor(cr, cg, cb, 0.95)
	lg.circle("fill", cx, cy, r)
	local text = tostring(cost)
	local font_px = math.max(12, math.floor(r * 1.35))
	local font = ui_fonts.get_pixel_operator(font_px)
	lg.setColor(0.96, 0.94, 0.9, 1)
	if font and font.getWidth and font.getHeight then
		lg.setFont(font)
		local tw = font:getWidth(text)
		local th = font:getHeight()
		lg.print(text, cx - tw * 0.5, cy - th * 0.5)
	else
		ui_fonts.set("body_small")
		lg.printf(text, cx - r, cy - r + 1, r * 2, "center")
	end
end

local function draw_card_in_rect(slot, card, can_afford)
	local lg = love.graphics
	local slot_bounds = { x = -slot.w * 0.5, y = -slot.h * 0.5, w = slot.w, h = slot.h }
	local inner = card_geometry.aspect_rect_in_bounds(slot_bounds)
	local x0, y0, w, h = inner.x, inner.y, inner.w, inner.h
	local vis = card_visual.merged(card)
	local regions = card_layout.face_regions(w, h)
	local bg = sprites.get_image(vis.background)
	if can_afford then
		lg.setColor(1, 1, 1, 1)
	else
		lg.setColor(0.62, 0.62, 0.66, 1)
	end
	if bg and bg ~= false then
		local dx, dy, _, _, sx, sy = card_geometry.image_draw_dest_stretch(slot_bounds, bg:getWidth(), bg:getHeight())
		lg.draw(bg, dx, dy, 0, sx, sy)
	else
		lg.setColor(0.55, 0.52, 0.48, 1)
		lg.rectangle("fill", x0, y0, w, h, 8, 8)
	end
	lg.setColor(1, 1, 1, 1)
	draw_energy_badge(lg, x0, y0, regions, card.energy_cost, vis.circle_color)
	local gfx = sprites.get_image(vis.graphic)
	if gfx and gfx ~= false then
		lg.setColor(1, 1, 1, 1)
		local art_bounds = {
			x = x0 + regions.art_x,
			y = y0 + regions.art_y,
			w = regions.art_w,
			h = regions.art_h,
		}
		local gdx, gdy, _, _, gsx, gsy = card_geometry.image_draw_dest(art_bounds, gfx:getWidth(), gfx:getHeight())
		lg.draw(gfx, gdx, gdy, 0, gsx, gsy)
	end
	local tr, tg3, tb3, _t3 = card_visual.rgba_from_hex(vis.title_box_color)
	lg.setColor(tr, tg3, tb3, 1)
	lg.rectangle("fill", x0 + regions.title_x, y0 + regions.title_y, regions.title_w, regions.title_h, 4, 4)
	ui_fonts.set("body_small")
	lg.setColor(0.08, 0.08, 0.1, 1)
	lg.printf(card.name or card.display_name or "", x0 + regions.title_x + 2, y0 + regions.title_y + 2, regions.title_w - 4, "center")
	local dr, dg4, db4, _d4 = card_visual.rgba_from_hex(vis.description_box_color)
	lg.setColor(dr, dg4, db4, 1)
	lg.rectangle("fill", x0 + regions.desc_x, y0 + regions.desc_y, regions.desc_w, regions.desc_h, 4, 4)
	ui_fonts.set("body_small")
	lg.printf(card.description or "", x0 + regions.desc_x + 4, y0 + regions.desc_y + 3, regions.desc_w - 8, "left")
	ui_fonts.apply_default()
end

local function draw_hand(game, layout)
	local lg = love.graphics
	local player = match_state.player_for_color(game, game.to_play)
	local hand = player.cards.hand.ids
	local selected = (M._card_ui and M._card_ui.selected_index) or nil
	local card_ui_state = M._card_ui or {}
	local armed_index = card_ui_state.hand_target_phase == "armed" and card_ui_state.armed_hand_index or nil
	local show_action_panel = selected ~= nil or armed_index ~= nil
	local popped_targets = card_ui_state.popped_target_indices or {}
	local invalid_target = card_ui_state.invalid_target_feedback
	local dragging_index = nil
	if M._card_ui and M._card_ui.drag_active and M._card_ui.moved and M._card_ui.drag_mode ~= "target_arrow" then
		dragging_index = M._card_ui.drag_index
	end
	local panel = layout.hand_panel
	local protrude = layout.hand_card_protrude or 44
	lg.setScissor(panel.x, panel.y, panel.w, panel.h + protrude)
	local slots = layout_mod.hand_fan_slots(layout, #hand)
	local function draw_card(slot, card_id)
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
		lg.setColor(1, 1, 1, 1)
		draw_card_in_rect(slot, card, can_afford)
		if invalid_target and invalid_target.object_type == "card" and invalid_target.hand_index == slot._index then
			lg.setColor(0.94, 0.22, 0.22, 0.95)
			lg.setLineWidth(4)
			lg.rectangle("line", -slot.w * 0.5 + 3, -slot.h * 0.5 + 3, slot.w - 6, slot.h - 6, 8, 8)
			lg.setLineWidth(1)
		end
		lg.pop()
	end
	for i = 1, #slots do
		slots[i]._index = i
		if i ~= selected and i ~= dragging_index and i ~= armed_index and not popped_targets[i] then
			draw_card(slots[i], hand[i])
		end
	end
	lg.setScissor()
	for i = 1, #slots do
		if popped_targets[i] and i ~= selected and i ~= armed_index then
			local popup = layout_mod.card_target_popup_rect(layout, i, #hand)
			if popup and hand[i] then
				draw_card(popup, hand[i])
			end
		end
	end
	if show_action_panel then
		if selected and slots[selected] and hand[selected] and selected ~= dragging_index then
			local focus = layout_mod.card_active_focus_rect(layout, selected, #hand)
			if focus then
				draw_card(focus, hand[selected])
			end
		end
		local use_button = layout_mod.card_use_button_rect(layout)
		if card_ui_state.can_use then
			lg.setColor(0.26, 0.56, 0.32, 0.92)
		else
			lg.setColor(0.38, 0.38, 0.4, 0.82)
		end
		lg.rectangle("fill", use_button.x, use_button.y, use_button.w, use_button.h, 6, 6)
		lg.setColor(config.COLOR_GRID[1], config.COLOR_GRID[2], config.COLOR_GRID[3], 1)
		lg.rectangle("line", use_button.x, use_button.y, use_button.w, use_button.h, 6, 6)
		ui_fonts.set("body")
		lg.setColor(0.96, 0.96, 0.96, 1)
		local action_label = card_ui_state.action_button_label or "Use"
		lg.printf(action_label, use_button.x, use_button.y + 10, use_button.w, "center")
		ui_fonts.set("body_small")
		local req = card_ui_state.requirement_text or ""
		if req ~= "" then
			lg.setColor(0.92, 0.92, 0.92, 0.95)
			lg.printf(req, use_button.x - 120, use_button.y + use_button.h + 2, use_button.w + 120, "right")
		end
		local reason = card_ui_state.validation_reason or card_ui_state.status_text or ""
		if reason ~= "" and not card_ui_state.can_use then
			lg.setColor(0.94, 0.44, 0.44, 0.95)
			lg.printf(reason, use_button.x - 220, use_button.y + use_button.h + 20, use_button.w + 220, "right")
		elseif (card_ui_state.status_text or "") ~= "" then
			lg.setColor(0.94, 0.44, 0.44, 0.95)
			lg.printf(card_ui_state.status_text, use_button.x - 220, use_button.y + use_button.h + 20, use_button.w + 220, "right")
		end
		local chip_rects = card_ui_state.target_chip_rects or {}
		local labels = card_ui_state.selected_target_labels or {}
		for i = 1, #chip_rects do
			local chip = chip_rects[i]
			lg.setColor(0.19, 0.21, 0.24, 0.92)
			lg.rectangle("fill", chip.x, chip.y, chip.w, chip.h, 6, 6)
			lg.setColor(0.42, 0.45, 0.5, 1)
			lg.rectangle("line", chip.x, chip.y, chip.w, chip.h, 6, 6)
			lg.setColor(0.96, 0.96, 0.96, 1)
			lg.printf(labels[i] or "Target", chip.x + 8, chip.y + 4, chip.w - 28, "left")
			lg.setColor(0.94, 0.44, 0.44, 1)
			lg.printf("×", chip.x + chip.w - 18, chip.y + 4, 12, "center")
		end
	end
	if dragging_index and hand[dragging_index] and not card_ui_state.drag_targeting and dragging_index ~= armed_index then
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
		draw_card(floating, hand[dragging_index])
		local use_button = layout_mod.card_use_button_rect(layout)
		if card_ui_state.can_use then
			lg.setColor(0.26, 0.56, 0.32, 0.92)
		else
			lg.setColor(0.38, 0.38, 0.4, 0.82)
		end
		lg.rectangle("fill", use_button.x, use_button.y, use_button.w, use_button.h, 6, 6)
		lg.setColor(config.COLOR_GRID[1], config.COLOR_GRID[2], config.COLOR_GRID[3], 1)
		lg.rectangle("line", use_button.x, use_button.y, use_button.w, use_button.h, 6, 6)
		ui_fonts.set("body")
		lg.setColor(0.96, 0.96, 0.96, 1)
		local action_label = card_ui_state.action_button_label or "Use"
		lg.printf(action_label, use_button.x, use_button.y + 10, use_button.w, "center")
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
				local bounce_y = ui_animations.board_stone_bounce_offset(r, c)
				local side = owner_side_from_stone_color(cell.color)
				draw_stone_chip(
					cell.kind,
					{ x = px - rad, y = py - rad - bounce_y, w = rad * 2, h = rad * 2 },
					side,
					false,
					cell.solidity
				)
			end
		end
	end
	local selected_targets = game.selected_card_targets or {}
	local invalid = M._card_ui and M._card_ui.invalid_target_feedback or nil
	for i = 1, #selected_targets do
		local target = selected_targets[i]
		if target.object_type == "stone" and target.row and target.col then
			local px, py = layout_mod.grid_to_pixel(layout, target.row, target.col)
			lg.setColor(0.96, 0.84, 0.22, 0.95)
			lg.setLineWidth(3)
			lg.circle("line", px, py, rad * 0.92)
		end
	end
	if invalid and invalid.object_type == "stone" and invalid.row and invalid.col then
		local px, py = layout_mod.grid_to_pixel(layout, invalid.row, invalid.col)
		lg.setColor(0.94, 0.22, 0.22, 0.95)
		lg.setLineWidth(4)
		lg.circle("line", px, py, rad * 0.98)
	end
	local selected_target = game.selected_card_target
	if selected_target and selected_target.row and selected_target.col then
		local px, py = layout_mod.grid_to_pixel(layout, selected_target.row, selected_target.col)
		lg.setColor(0.96, 0.84, 0.22, 0.95)
		lg.setLineWidth(3)
		lg.circle("line", px, py, rad * 0.92)
	end
	lg.setLineWidth(1)
	local probe = M._influence_probe
	if probe and probe.contributors then
		local marked = {}
		local owners = { config.OWNER_BLACK, config.OWNER_WHITE }
		if probe.owner == config.OWNER_BLACK then
			owners = { config.OWNER_BLACK }
		elseif probe.owner == config.OWNER_WHITE then
			owners = { config.OWNER_WHITE }
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
		local side = popup_state.ring_side or "black"
		draw_stone_chip(popup_state.stones[i], rects[i], side, popup_state.focus_index == i)
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
	ui_fonts.apply_default()
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
	local card_ui_state = M._card_ui or nil
	if
		card_ui_state
		and card_ui_state.drag_active
		and card_ui_state.drag_mode == "target_arrow"
		and card_ui_state.moved
	then
		draw_card_target_arrow(
			card_ui_state.drag_arrow_from_x,
			card_ui_state.drag_arrow_from_y,
			card_ui_state.drag_arrow_to_x,
			card_ui_state.drag_arrow_to_y,
			card_ui_state.drag_target_valid
		)
	end
	draw_popup(layout, popup_state)
	if stone_drag and stone_drag.active and stone_drag.moved and stone_drag.stone_id then
		local d = layout_mod.board_stone_outer_diameter(layout)
		local half = d * 0.5
		draw_stone_chip(
			stone_drag.stone_id,
			{ x = stone_drag.current_x - half, y = stone_drag.current_y - half, w = d, h = d },
			game.to_play,
			false
		)
	end
	local draw_anim = M._stone_draw_anim
	if draw_anim.current then
		local event = draw_anim.current
		local actor = event.actor
		if actor == "black" or actor == "white" then
			local start_rect = layout_mod.player_action_icon_rects(layout)[1]
			local end_rects = layout_mod.stone_chip_rects(
				layout,
				#match_state.player_for_color(game, actor).stones.playable_stones
			)
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
				local w = target.w
				local h = target.h
				draw_stone_chip(event.stone_id, { x = x - w * 0.5, y = y - h * 0.5, w = w, h = h }, actor, false)
			end
		end
	end
	ui_animations.draw(game, layout)
	draw_stance_detail_popup(game, layout)
	lg.setColor(1, 1, 1, 1)
end

function M.update(dt, game, layout)
	ui_animations.update(dt, game, layout)
	resolver.flush_pending_turn_if_ready(game)
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
		{ owner_key = config.OWNER_BLACK, box = layout.player_stances_panel, entries = stances.all_active_stances(player, game, config.OWNER_BLACK) },
		{ owner_key = config.OWNER_WHITE, box = layout.opponent_stances_panel, entries = stances.all_active_stances(opp, game, config.OWNER_WHITE) },
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
