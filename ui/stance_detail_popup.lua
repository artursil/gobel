--- Floating title/description panel shown beside a selected stance card.
--- @module ui.stance_detail_popup

local ui_fonts = require("ui.fonts")
local object_descriptions = require("ui.object_descriptions")

local M = {}

local GOLDEN = { 0.82, 0.62, 0.18, 0.9 }
local WHITE_BOX = { 1, 1, 1, 1 }
local SILVER_BOX = { 0.72, 0.74, 0.78, 1 }
local TITLE_TEXT = { 0.06, 0.06, 0.08, 1 }
local DESC_TEXT = { 1, 1, 1, 1 }
local STATUS_TEXT = { 0.88, 0.9, 0.94, 1 }

local OUTER_PAD = 12
local INNER_PAD = 10
local SECTION_GAP = 10
local STATUS_GAP = 6
local POPUP_W = 268
local TITLE_BOX_MIN_H = 40
local CORNER = 8
local ANCHOR_GAP = 10

--- @param text string
--- @param width number
--- @param font love.Font
--- @return number
local function wrapped_text_height(text, width, font)
	local _, lines = font:getWrap(text or "", width)
	return math.max(font:getHeight(), #lines * font:getHeight())
end

--- @param desc_lines table|string
--- @param desc_w number
--- @param desc_font love.Font
--- @return number
local function description_block_height(desc_lines, desc_w, desc_font)
	if type(desc_lines) == "string" then
		return wrapped_text_height(desc_lines, desc_w, desc_font)
	end
	local h = wrapped_text_height(desc_lines.static or "", desc_w, desc_font)
	if desc_lines.status and desc_lines.status ~= "" then
		h = h + STATUS_GAP + desc_font:getHeight()
	end
	return h
end

--- @param anchor table
--- @param title string
--- @param desc_lines table|string
--- @param screen_w number
--- @param screen_h number
--- @return table
function M.layout(anchor, title, desc_lines, screen_w, screen_h)
	local title_font = ui_fonts.get_bold("body")
	local desc_font = ui_fonts.get_bold("body_small")

	local inner_w = POPUP_W - OUTER_PAD * 2
	local desc_w = inner_w - INNER_PAD * 2
	local desc_h = description_block_height(desc_lines, desc_w, desc_font) + INNER_PAD * 2
	desc_h = math.max(52, desc_h)

	local title_text_w = title_font:getWidth(title or "")
	local title_box_w = math.min(inner_w, title_text_w + INNER_PAD * 2)
	local title_box_h = math.max(TITLE_BOX_MIN_H, title_font:getHeight() + INNER_PAD * 2)

	local popup_w = math.max(POPUP_W, title_box_w + OUTER_PAD * 2)
	local inner_w_actual = popup_w - OUTER_PAD * 2
	title_box_w = math.min(inner_w_actual, title_text_w + INNER_PAD * 2)
	local desc_w_actual = inner_w_actual - INNER_PAD * 2
	desc_h = description_block_height(desc_lines, desc_w_actual, desc_font) + INNER_PAD * 2
	desc_h = math.max(52, desc_h)

	local outer_h = OUTER_PAD * 2 + title_box_h + SECTION_GAP + desc_h

	local x = anchor.x + anchor.w + ANCHOR_GAP
	if x + popup_w > screen_w - 8 then
		x = anchor.x - popup_w - ANCHOR_GAP
	end
	if x < 8 then
		x = 8
	end

	local y = anchor.y + math.floor(anchor.h * 0.5) - math.floor(outer_h * 0.5)
	if y < 8 then
		y = 8
	end
	if y + outer_h > screen_h - 8 then
		y = screen_h - 8 - outer_h
	end

	local title_box = {
		x = x + math.floor((popup_w - title_box_w) * 0.5),
		y = y + OUTER_PAD,
		w = title_box_w,
		h = title_box_h,
	}

	local desc_box = {
		x = x + OUTER_PAD,
		y = title_box.y + title_box.h + SECTION_GAP,
		w = inner_w_actual,
		h = desc_h,
	}

	return {
		x = x,
		y = y,
		w = popup_w,
		h = outer_h,
		title_box = title_box,
		desc_box = desc_box,
		title = title,
		desc_lines = type(desc_lines) == "table" and desc_lines or { static = desc_lines or "", status = nil },
		title_text_w = title_box_w - INNER_PAD * 2,
		desc_text_w = desc_w_actual,
	}
end

--- @param box table
--- @return nil
function M.draw(box)
	if not box then
		return
	end
	local lg = love.graphics

	lg.setColor(GOLDEN[1], GOLDEN[2], GOLDEN[3], GOLDEN[4])
	lg.rectangle("fill", box.x, box.y, box.w, box.h, CORNER, CORNER)

	local tb = box.title_box
	lg.setColor(WHITE_BOX[1], WHITE_BOX[2], WHITE_BOX[3], WHITE_BOX[4])
	lg.rectangle("fill", tb.x, tb.y, tb.w, tb.h, 6, 6)

	local db = box.desc_box
	lg.setColor(SILVER_BOX[1], SILVER_BOX[2], SILVER_BOX[3], SILVER_BOX[4])
	lg.rectangle("fill", db.x, db.y, db.w, db.h, 6, 6)

	local title_font = ui_fonts.get_bold("body")
	lg.setFont(title_font)
	lg.setColor(TITLE_TEXT[1], TITLE_TEXT[2], TITLE_TEXT[3], TITLE_TEXT[4])
	lg.printf(
		box.title,
		tb.x + INNER_PAD,
		tb.y + math.floor((tb.h - title_font:getHeight()) * 0.5),
		box.title_text_w,
		"center"
	)

	local desc_font = ui_fonts.get_bold("body_small")
	lg.setFont(desc_font)
	local desc_lines = box.desc_lines
	local text_x = db.x + INNER_PAD
	local text_y = db.y + INNER_PAD
	local text_w = box.desc_text_w

	lg.setColor(DESC_TEXT[1], DESC_TEXT[2], DESC_TEXT[3], DESC_TEXT[4])
	lg.printf(desc_lines.static or "", text_x, text_y, text_w, "left")

	if desc_lines.status and desc_lines.status ~= "" then
		local static_h = wrapped_text_height(desc_lines.static or "", text_w, desc_font)
		lg.setColor(STATUS_TEXT[1], STATUS_TEXT[2], STATUS_TEXT[3], STATUS_TEXT[4])
		lg.printf(desc_lines.status, text_x, text_y + static_h + STATUS_GAP, text_w, "left")
	end

	ui_fonts.apply_default()
end

--- Build layout from a stance definition and game state (convenience for render).
--- @param anchor table
--- @param def table|nil
--- @param state table|nil
--- @param owner string
--- @param screen_w number
--- @param screen_h number
--- @return table|nil
function M.layout_for_def(anchor, def, state, owner, screen_w, screen_h)
	if not def then
		return nil
	end
	local title = def.display_name or def.name or ""
	local desc_lines = object_descriptions.get_lines(def, state, owner)
	return M.layout(anchor, title, desc_lines, screen_w, screen_h)
end

--- @param box table|nil
--- @param x number
--- @param y number
--- @return boolean
function M.contains(box, x, y)
	if not box then
		return false
	end
	return x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h
end

return M
