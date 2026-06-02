--- Unified playing-card face drawing for hand, focus, and deck/discard popups.
--- @module ui.card_draw

local card_geometry = require("ui.card_geometry")
local card_layout = require("ui.card_layout")
local card_visual = require("ui.card_visual")
local sprites = require("ui.sprites")
local ui_fonts = require("ui.fonts")

local M = {}

--- @param lg love.graphics
--- @param x0 number
--- @param y0 number
--- @param regions table
--- @param cost number
--- @param circle_color string
--- @return nil
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

--- Draws a card face into ``slot`` (`w`, `h`, optional `x`/`y` when not centered).
--- @param slot table
--- @param card_def table
--- @param opts table|nil can_afford?, highlighted?, centered?
--- @return nil
function M.draw_card_face(slot, card_def, opts)
	if not card_def then
		return
	end
	opts = opts or {}
	local can_afford = opts.can_afford ~= false
	local highlighted = opts.highlighted or false
	local centered = opts.centered ~= false
	local lg = love.graphics
	local slot_bounds
	if centered then
		slot_bounds = { x = -slot.w * 0.5, y = -slot.h * 0.5, w = slot.w, h = slot.h }
	else
		slot_bounds = { x = slot.x, y = slot.y, w = slot.w, h = slot.h }
	end
	local inner = card_geometry.aspect_rect_in_bounds(slot_bounds)
	local x0, y0, w, h = inner.x, inner.y, inner.w, inner.h
	local vis = card_visual.merged(card_def)
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
	draw_energy_badge(lg, x0, y0, regions, card_def.energy_cost or 0, vis.circle_color)
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
	local tr, tg, tb, _ = card_visual.rgba_from_hex(vis.title_box_color)
	lg.setColor(tr, tg, tb, 1)
	lg.rectangle("fill", x0 + regions.title_x, y0 + regions.title_y, regions.title_w, regions.title_h, 4, 4)
	ui_fonts.set("body_small")
	lg.setColor(0.08, 0.08, 0.1, 1)
	lg.printf(
		card_def.name or card_def.display_name or "",
		x0 + regions.title_x + 2,
		y0 + regions.title_y + 2,
		regions.title_w - 4,
		"center"
	)
	local dr, dg, db, _ = card_visual.rgba_from_hex(vis.description_box_color)
	lg.setColor(dr, dg, db, 1)
	lg.rectangle("fill", x0 + regions.desc_x, y0 + regions.desc_y, regions.desc_w, regions.desc_h, 4, 4)
	ui_fonts.set("body_small")
	lg.printf(card_def.description or "", x0 + regions.desc_x + 4, y0 + regions.desc_y + 3, regions.desc_w - 8, "left")
	ui_fonts.apply_default()
	if highlighted then
		lg.setColor(0.26, 0.54, 0.78, 0.95)
		lg.setLineWidth(3)
		lg.rectangle("line", slot_bounds.x + 2, slot_bounds.y + 2, slot_bounds.w - 4, slot_bounds.h - 4, 6, 6)
		lg.setLineWidth(1)
	end
end

return M
