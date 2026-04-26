--- Maps between window pixels and board + panelized UI interactions.

local config = require("config")

local M = {}

--- Computes pixel origin, cell spacing, and reserved chrome for score, incoming stones, and status.
--- @param window_w number
--- @param window_h number
--- @return table layout
function M.from_window(window_w, window_h)
	local outer = 12
	local gap = 10
	local side_w = math.max(190, math.floor(window_w * 0.2))
	local message_h = math.max(64, math.floor(window_h * 0.1))
	local bottom_h = math.max(190, math.floor(window_h * 0.26))
	local inner_w = window_w - outer * 2
	local center_w = inner_w - side_w * 2 - gap * 2
	local center_x = outer + side_w + gap
	local top_y = outer
	local bottom_y = window_h - outer - bottom_h
	local board_y = top_y + message_h + gap
	local board_h = bottom_y - gap - board_y
	local n = config.BOARD_SIZE
	local span = n - 1
	local board_side = math.min(center_w, board_h)
	local cell = board_side / span
	local ox = center_x + (center_w - board_side) * 0.5
	local oy = board_y + (board_h - board_side) * 0.5
	local column_h = window_h - outer * 2
	local score_h = math.max(86, math.floor(column_h * 0.16))
	local pouch_h = math.max(88, math.floor(column_h * 0.16))
	local left_mid_h = column_h - score_h - pouch_h - gap * 2
	local right_mid_h = left_mid_h
	local selector_h = math.max(56, math.floor(bottom_h * 0.28))
	local hand_y = bottom_y + selector_h + gap
	local hand_h = bottom_h - selector_h - gap
	local hand_w = math.floor(center_w * 0.72)
	local hand_x = center_x + math.floor((center_w - hand_w) * 0.5)
	return {
		cell = cell,
		ox = ox,
		oy = oy,
		n = n,
		score_player = { x = outer, y = outer, w = side_w, h = score_h },
		score_opponent = { x = window_w - outer - side_w, y = outer, w = side_w, h = score_h },
		left_panel = { x = outer, y = outer, w = side_w, h = column_h },
		right_panel = { x = window_w - outer - side_w, y = outer, w = side_w, h = column_h },
		player_poses_panel = { x = outer, y = outer + score_h + gap, w = side_w, h = math.floor(left_mid_h * 0.62) },
		player_resources_panel = {
			x = outer,
			y = outer + score_h + gap + math.floor(left_mid_h * 0.62) + gap,
			w = side_w,
			h = left_mid_h - math.floor(left_mid_h * 0.62) - gap,
		},
		pouch_panel = { x = outer, y = window_h - outer - pouch_h, w = side_w, h = pouch_h },
		opponent_poses_panel = {
			x = window_w - outer - side_w,
			y = outer + score_h + gap,
			w = side_w,
			h = math.floor(right_mid_h * 0.72),
		},
		opponent_resources_panel = {
			x = window_w - outer - side_w,
			y = outer + score_h + gap + math.floor(right_mid_h * 0.72) + gap,
			w = side_w,
			h = right_mid_h - math.floor(right_mid_h * 0.72) - gap,
		},
		deck_panel = { x = window_w - outer - side_w, y = window_h - outer - pouch_h, w = side_w, h = pouch_h },
		board = { x = center_x, y = board_y, w = center_w, h = board_h },
		message_panel = { x = center_x, y = top_y, w = center_w, h = message_h },
		stone_selector_panel = { x = hand_x, y = bottom_y, w = hand_w, h = selector_h },
		active_stone_panel = { x = hand_x, y = bottom_y, w = hand_w, h = selector_h },
		hand_panel = { x = hand_x, y = hand_y, w = hand_w, h = hand_h },
		board_metrics = { x = ox, y = oy, w = board_side, h = board_side, n = n, cell = cell, ox = ox, oy = oy },
		popup = {
			x = center_x + math.floor(center_w * 0.08),
			y = top_y + math.floor((window_h - outer - top_y) * 0.1),
			w = math.floor(center_w * 0.84),
			h = math.floor((window_h - outer - top_y) * 0.8),
		},
		stone_chip_gap = 8,
		hand_card_gap = 8,
	}
end

--- Converts grid coordinates to the pixel center of that intersection.
--- @param layout table
--- @param row integer
--- @param col integer
--- @return number px
--- @return number py
function M.grid_to_pixel(layout, row, col)
	local px = layout.ox + (col - 1) * layout.cell
	local py = layout.oy + (row - 1) * layout.cell
	return px, py
end

--- Finds the nearest intersection to a pixel point within hit radius.
--- @param layout table
--- @param px number
--- @param py number
--- @return integer|nil row
--- @return integer|nil col
function M.pixel_to_grid(layout, px, py)
	local board = layout.board_metrics
	if px < board.x or px > board.x + board.w or py < board.y or py > board.y + board.h then
		return nil, nil
	end
	local n = layout.n
	local best_r, best_c = nil, nil
	local best_d = (layout.cell * 0.55) ^ 2
	for r = 1, n do
		for c = 1, n do
			local gx, gy = M.grid_to_pixel(layout, r, c)
			local dx = px - gx
			local dy = py - gy
			local d = dx * dx + dy * dy
			if d <= best_d then
				best_d = d
				best_r, best_c = r, c
			end
		end
	end
	return best_r, best_c
end

function M.hand_card_rects(layout, card_count)
	local panel = layout.hand_panel
	local pad = 10
	local gap = layout.hand_card_gap
	local slots = math.max(card_count, 1)
	local w = math.floor((panel.w - pad * 2 - gap * (slots - 1)) / slots)
	w = math.max(84, math.min(126, w))
	local h = panel.h - 20
	local total = slots * w + gap * (slots - 1)
	local x0 = panel.x + math.floor((panel.w - total) * 0.5)
	local y = panel.y + 10
	local out = {}
	for i = 1, card_count do
		out[i] = { x = x0 + (i - 1) * (w + gap), y = y, w = w, h = h }
	end
	return out
end

function M.hand_index_at(layout, px, py, card_count)
	local slots = M.hand_fan_slots(layout, card_count)
	for i = #slots, 1, -1 do
		local slot = slots[i]
		local cx = slot.x + slot.w * 0.5
		local cy = slot.y + slot.h * 0.5
		local dx = px - cx
		local dy = py - cy
		local c = math.cos(-slot.angle)
		local s = math.sin(-slot.angle)
		local lx = dx * c - dy * s + slot.w * 0.5
		local ly = dx * s + dy * c + slot.h * 0.5
		if lx >= 0 and lx <= slot.w and ly >= 0 and ly <= slot.h then
			return i
		end
	end
	return nil
end

function M.hand_fan_slots(layout, card_count)
	local panel = layout.hand_panel
	local slots = math.max(card_count, 1)
	local card_w = math.min(138, math.max(96, math.floor(panel.w * 0.28)))
	local card_h = math.min(188, math.max(142, math.floor(panel.h * 1.3)))
	local overlap = math.floor(card_w * 0.42)
	local step = card_w - overlap
	local total_w = card_w + (slots - 1) * step
	local x0 = panel.x + math.floor((panel.w - total_w) * 0.5)
	local y = panel.y + panel.h - math.floor(card_h * 0.64)
	local max_angle = 0.28
	local mid = (slots + 1) * 0.5
	local out = {}
	for i = 1, card_count do
		local offset = (slots == 1) and 0 or ((i - mid) / (slots - 1))
		out[i] = {
			x = x0 + (i - 1) * step,
			y = y,
			w = card_w,
			h = card_h,
			angle = offset * max_angle,
		}
	end
	return out
end

function M.card_use_button_rect(layout)
	local panel = layout.hand_panel
	local w = 92
	local h = 38
	return {
		x = panel.x + panel.w - w - 10,
		y = panel.y + 8,
		w = w,
		h = h,
	}
end

function M.stone_chip_rects(layout, stone_count)
	local panel = layout.stone_selector_panel
	local pad = 10
	local gap = layout.stone_chip_gap
	local slots = math.max(stone_count, 1)
	local w = math.floor((panel.w - pad * 2 - gap * (slots - 1)) / slots)
	w = math.max(70, math.min(110, w))
	local h = panel.h - 20
	local total = slots * w + gap * (slots - 1)
	local x0 = panel.x + math.floor((panel.w - total) * 0.5)
	local y = panel.y + 10
	local out = {}
	for i = 1, stone_count do
		out[i] = { x = x0 + (i - 1) * (w + gap), y = y, w = w, h = h }
	end
	return out
end

function M.stone_index_at(layout, px, py, stone_count)
	local rects = M.stone_chip_rects(layout, stone_count)
	for i = 1, #rects do
		local r = rects[i]
		if px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h then
			return i
		end
	end
	return nil
end

function M.popup_close_rect(layout)
	local p = layout.popup
	return { x = p.x + p.w - 96, y = p.y + 10, w = 80, h = 28 }
end

function M.pouch_popup_grid_rects(layout, count)
	local p = layout.popup
	local cols = 5
	local pad = 16
	local gap = 8
	local top = 52
	local chip = math.floor((p.w - pad * 2 - gap * (cols - 1)) / cols)
	chip = math.max(56, math.min(78, chip))
	local out = {}
	for i = 1, count do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		out[i] = {
			x = p.x + pad + col * (chip + gap),
			y = p.y + top + row * (chip + gap),
			w = chip,
			h = chip,
		}
	end
	return out
end

return M
