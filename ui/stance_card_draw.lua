--- Shared stance card art: portrait and frame share one stretched 2.5×3.5 rect.
--- @module ui.stance_card_draw

local card_geometry = require("ui.card_geometry")
local sprites = require("ui.sprites")

local M = {}

--- @param rect table
--- @param image love.graphics.Image
--- @return nil
local function draw_image_in_card_rect(rect, image)
	local lg = love.graphics
	local iw = image:getWidth()
	local ih = image:getHeight()
	local dx, dy, _, _, sx, sy = card_geometry.image_draw_dest_stretch(rect, iw, ih)
	lg.setColor(1, 1, 1, 1)
	lg.draw(image, dx, dy, 0, sx, sy)
end

--- @param rect table x,y,w,h
--- @param stance table|nil
--- @return nil
function M.draw_portrait(rect, stance)
	local v = stance and stance.visual or {}
	local path = v.graphic
	local g = path and sprites.get_image(path)
	if not g or g == false then
		return
	end
	draw_image_in_card_rect(rect, g)
end

--- @param rect table
--- @param stance table|nil
--- @return nil
function M.draw_frame(rect, stance)
	local v = stance and stance.visual or {}
	local path = v.frame
	local f = path and sprites.get_image(path)
	if not f or f == false then
		return
	end
	draw_image_in_card_rect(rect, f)
end

--- @param rect table
--- @param stance table|nil
--- @return nil
function M.draw_portrait_and_frame(rect, stance)
	M.draw_portrait(rect, stance)
	M.draw_frame(rect, stance)
end

return M
