local cells = require("board")
local config = require("config")
local content = require("content")
local layout_mod = require("layout")
local match_state = require("match_state")
local messages = require("messages")
local poses = require("poses")
local pouch = require("pouch")

local M = {}
local SCORE_ANIM_BASE_DURATION = 0.45
local score_anim_font = nil
M._score_anim = {
	queue = {},
	current = nil,
	remaining = 0,
	duration = 0,
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

local function draw_score_box(game, box, side, title)
	local lg = love.graphics
	local player = match_state.player_for_color(game, side)
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	lg.printf(title, box.x, box.y + 8, box.w, "center")
	lg.printf(string.format("%d x %d", player.score.points or 0, player.score.mult or 0), box.x, box.y + 34, box.w, "center")
	lg.printf(tostring(player.score.total or 0), box.x, box.y + 60, box.w, "center")
end

local function draw_poses(box, pose_ids)
	local lg = love.graphics
	local cols = 2
	local gap = 6
	local pad = 8
	local cell_w = math.floor((box.w - pad * 2 - gap) / cols)
	local row_h = 20
	for i = 1, #pose_ids do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local x = box.x + pad + col * (cell_w + gap)
		local y = box.y + 28 + row * (row_h + gap)
		local pose = content.get_pose(pose_ids[i])
		lg.setColor(0.3, 0.26, 0.2, 0.65)
		lg.rectangle("fill", x, y, cell_w, row_h, 4, 4)
		lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
		lg.printf((pose and pose.display_name) or pose_ids[i], x + 3, y + 3, cell_w - 6, "center")
	end
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
	draw_panel(layout.left_panel)
	draw_panel(layout.right_panel)
	draw_panel(layout.player_poses_panel)
	draw_panel(layout.player_resources_panel)
	draw_panel(layout.opponent_poses_panel)
	draw_panel(layout.opponent_resources_panel)
	draw_panel(layout.pouch_panel)
	draw_panel(layout.deck_panel)
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	lg.printf("Player Poses", layout.player_poses_panel.x, layout.player_poses_panel.y + 8, layout.player_poses_panel.w, "center")
	draw_poses(layout.player_poses_panel, poses.active_pose_ids(player))
	lg.printf("Player Resources", layout.player_resources_panel.x, layout.player_resources_panel.y + 8, layout.player_resources_panel.w, "center")
	lg.printf(string.format("Energy: %d/%d", player.resources.energy_current, player.resources.energy_max), layout.player_resources_panel.x + 10, layout.player_resources_panel.y + 34, layout.player_resources_panel.w - 20, "left")
	lg.printf(string.format("Money: %d", player.resources.money), layout.player_resources_panel.x + 10, layout.player_resources_panel.y + 58, layout.player_resources_panel.w - 20, "left")
	lg.printf("Player Pouch", layout.pouch_panel.x, layout.pouch_panel.y + 8, layout.pouch_panel.w, "center")
	lg.printf(string.format("Stones: %d", pouch.remaining_count(player.stones.pouch)), layout.pouch_panel.x + 10, layout.pouch_panel.y + 34, layout.pouch_panel.w - 20, "left")
	lg.printf("Opponent Poses", layout.opponent_poses_panel.x, layout.opponent_poses_panel.y + 8, layout.opponent_poses_panel.w, "center")
	draw_poses(layout.opponent_poses_panel, poses.active_pose_ids(opp))
	lg.printf("Opponent Energy", layout.opponent_resources_panel.x, layout.opponent_resources_panel.y + 8, layout.opponent_resources_panel.w, "center")
	lg.printf(string.format("%d/%d", opp.resources.energy_current, opp.resources.energy_max), layout.opponent_resources_panel.x + 10, layout.opponent_resources_panel.y + 34, layout.opponent_resources_panel.w - 20, "center")
	lg.printf("Player Deck", layout.deck_panel.x, layout.deck_panel.y + 8, layout.deck_panel.w, "center")
	lg.printf(
		string.format("Deck: %d  Played: %d", #player.cards.deck.ids, #player.cards.discard.ids),
		layout.deck_panel.x + 10,
		layout.deck_panel.y + 34,
		layout.deck_panel.w - 20,
		"left"
	)
end

local function stone_color_for_side(side)
	if side == "black" then
		return config.COLOR_BLACK_STONE
	end
	return config.COLOR_WHITE_STONE
end

local function draw_selector(game, layout, popup_state)
	local player = match_state.player_for_color(game, "black")
	local rects = layout_mod.stone_chip_rects(layout, #player.stones.playable_stones)
	local selected_slot = popup_state and popup_state.selected_slot or nil
	if selected_slot and (selected_slot < 1 or selected_slot > #player.stones.playable_stones) then
		selected_slot = nil
	end
	if not selected_slot then
		for i = 1, #player.stones.playable_stones do
			if player.stones.playable_stones[i] == player.stones.selected_stone then
				selected_slot = i
				break
			end
		end
	end
	for i = 1, #rects do
		local rect = rects[i]
		local stone_id = player.stones.playable_stones[i]
		draw_stone_chip(stone_id, rect, stone_color_for_side("black"), selected_slot == i)
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

local function draw_board(game, layout, hover_row, hover_col, show_hover)
	local lg = love.graphics
	draw_panel(layout.board)
	local territory = game.territory
	local n = layout.board_metrics.n
	if territory then
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
	if hover_row and hover_col and show_hover then
		local px, py = layout_mod.grid_to_pixel(layout, hover_row, hover_col)
		lg.setColor(config.COLOR_HIGHLIGHT[1], config.COLOR_HIGHLIGHT[2], config.COLOR_HIGHLIGHT[3], config.COLOR_HIGHLIGHT[4])
		lg.circle("fill", px, py, layout.board_metrics.cell * 0.2)
	end
end

local function draw_popup(layout, popup_state)
	if not popup_state or popup_state.mode == "none" then
		return
	end
	local lg = love.graphics
	if popup_state.mode == "selector-details" and popup_state.stone_id then
		local stone = content.get_stone(popup_state.stone_id)
		if stone then
			local anchor = popup_state.anchor_rect
			if anchor then
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
		end
	elseif popup_state.mode == "pouch-browser" then
		local box = layout.popup
		lg.setColor(0, 0, 0, 0.45)
		lg.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
		draw_panel(box)
		local close = layout_mod.popup_close_rect(layout)
		lg.setColor(0.4, 0.2, 0.2, 0.85)
		lg.rectangle("fill", close.x, close.y, close.w, close.h, 4, 4)
		lg.setColor(0.95, 0.95, 0.95, 1)
		lg.printf("Close", close.x, close.y + 6, close.w, "center")
		lg.printf("Pouch Browser", box.x + 20, box.y + 18, box.w - 140, "left")
		local rects = layout_mod.pouch_popup_grid_rects(layout, #popup_state.stones)
		for i = 1, #rects do
			local rect = rects[i]
			local stone_id = popup_state.stones[i]
			draw_stone_chip(stone_id, rect, stone_color_for_side("black"), popup_state.focus_index == i)
		end
		if popup_state.focus_index then
			local stone = content.get_stone(popup_state.stones[popup_state.focus_index])
			if stone then
				lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
				lg.printf(stone.name, box.x + 20, box.y + box.h - 86, box.w - 40, "left")
				lg.printf(stone.description, box.x + 20, box.y + box.h - 58, box.w - 40, "left")
			end
		end
	elseif popup_state.mode == "deck-browser" then
		local box = layout.popup
		lg.setColor(0, 0, 0, 0.45)
		lg.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
		draw_panel(box)
		local close = layout_mod.popup_close_rect(layout)
		lg.setColor(0.4, 0.2, 0.2, 0.85)
		lg.rectangle("fill", close.x, close.y, close.w, close.h, 4, 4)
		lg.setColor(0.95, 0.95, 0.95, 1)
		lg.printf("Close", close.x, close.y + 6, close.w, "center")
		lg.printf("Deck Browser", box.x + 20, box.y + 18, box.w - 140, "left")
		local deck_cards = popup_state.cards or {}
		local played_cards = popup_state.played_cards or {}
		local function draw_card_tile(card_id, rect, highlighted)
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
		local y_top = box.y + 52
		lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
		lg.printf("Deck", box.x + 20, y_top - 20, box.w - 40, "left")
		local deck_rects = layout_mod.pouch_popup_grid_rects(layout, #deck_cards)
		for i = 1, #deck_rects do
			local rect = deck_rects[i]
			draw_card_tile(deck_cards[i], rect, popup_state.focus_group == "deck" and popup_state.focus_index == i)
		end
		local played_offset_y = y_top + 160
		lg.printf("Played", box.x + 20, played_offset_y - 20, box.w - 40, "left")
		local cols = 5
		local gap = 8
		local pad = 16
		local chip = math.floor((box.w - pad * 2 - gap * (cols - 1)) / cols)
		chip = math.max(56, math.min(78, chip))
		for i = 1, #played_cards do
			local col = (i - 1) % cols
			local row = math.floor((i - 1) / cols)
			local rect = {
				x = box.x + pad + col * (chip + gap),
				y = played_offset_y + row * (chip + gap),
				w = chip,
				h = chip,
			}
			draw_card_tile(played_cards[i], rect, popup_state.focus_group == "played" and popup_state.focus_index == i)
		end
		if popup_state.focus_group and popup_state.focus_index then
			local source = popup_state.focus_group == "played" and played_cards or deck_cards
			local card = content.get_card(source[popup_state.focus_index])
			if card then
				lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3], 1)
				lg.printf(card.name or card.display_name, box.x + 20, box.y + box.h - 86, box.w - 40, "left")
				lg.printf(card.description or "", box.x + 20, box.y + box.h - 58, box.w - 40, "left")
			end
		end
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
	if popup_state.mode == "deck-browser" then
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
	lg.clear(config.COLOR_BOARD[1], config.COLOR_BOARD[2], config.COLOR_BOARD[3])
	draw_message(game, layout.message_panel)
	draw_panel(layout.score_player)
	draw_panel(layout.score_opponent)
	draw_score_box(game, layout.score_player, "black", "Player Score")
	draw_score_box(game, layout.score_opponent, "white", "Opponent Score")
	draw_side_columns(game, layout)
	draw_selector(game, layout, popup_state)
	draw_hand(game, layout)
	draw_board(game, layout, hover_row, hover_col, show_hover)
	draw_popup(layout, popup_state)
	if stone_drag and stone_drag.active and stone_drag.moved and stone_drag.stone_id then
		draw_stone_chip(
			stone_drag.stone_id,
			{ x = stone_drag.current_x - 28, y = stone_drag.current_y - 28, w = 56, h = 56 },
			stone_color_for_side("black"),
			false
		)
	end
	lg.setColor(1, 1, 1, 1)
end

function M.update(dt, game)
	local anim = M._score_anim
	local events = game.messages.score_events or {}
	for i = 1, #events do
		anim.queue[#anim.queue + 1] = events[i]
	end
	game.messages.score_events = {}
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

return M
