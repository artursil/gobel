--- Shared stance card art: portrait graphic inside an inner rect, frame over the full card.
--- Used by ``render.draw_stance_tile`` and ``ui.animation_kinds`` stance shake.
--- @module ui.stance_card_draw

local M = {}

local image_path_cache = {}

local STANCE_ART_INSET_FRAC = 0.11

--- @param path string
--- @return love.graphics.Image|false|nil
local function get_image_at_path(path)
	if image_path_cache[path] ~= nil then
		return image_path_cache[path]
	end
	local ok, image = pcall(love.graphics.newImage, path)
	image_path_cache[path] = ok and image or false
	return image_path_cache[path]
end

--- @param rect table
--- @return table
local function stance_art_inner_rect(rect)
	local m = math.min(rect.w, rect.h) * STANCE_ART_INSET_FRAC
	return {
		x = rect.x + m,
		y = rect.y + m,
		w = math.max(1, rect.w - 2 * m),
		h = math.max(1, rect.h - 2 * m),
	}
end

--- @param img love.graphics.Image
--- @param rect table
--- @return number dx
--- @return number dy
--- @return number dw
--- @return number dh
local function stance_image_contain_dest(img, rect)
	local iw = img:getWidth()
	local ih = img:getHeight()
	local sx = rect.w / iw
	local sy = rect.h / ih
	local s = math.min(sx, sy)
	local dw = iw * s
	local dh = ih * s
	local dx = rect.x + (rect.w - dw) * 0.5
	local dy = rect.y + (rect.h - dh) * 0.5
	return dx, dy, dw, dh
end

--- Portrait only (inside inner rect). Skips when there is no graphic asset.
--- @param rect table x,y,w,h
--- @param stance table|nil
--- @return nil
function M.draw_portrait(rect, stance)
	local lg = love.graphics
	local v = stance and stance.visual or {}
	local path = v.graphic
	local g = path and get_image_at_path(path)
	if not g or g == false then
		return
	end
	local inner = stance_art_inner_rect(rect)
	local dx, dy, dw, dh = stance_image_contain_dest(g, inner)
	lg.setColor(1, 1, 1, 1)
	lg.draw(g, dx, dy, 0, dw / g:getWidth(), dh / g:getHeight())
end

--- Frame scaled to the full card rect. Skips when there is no frame asset.
--- @param rect table
--- @param stance table|nil
--- @return nil
function M.draw_frame(rect, stance)
	local lg = love.graphics
	local v = stance and stance.visual or {}
	local path = v.frame
	local f = path and get_image_at_path(path)
	if not f or f == false then
		return
	end
	lg.setColor(1, 1, 1, 1)
	lg.draw(f, rect.x, rect.y, 0, rect.w / f:getWidth(), rect.h / f:getHeight())
end

--- Portrait then frame (idle “front” art stack, no text).
--- @param rect table
--- @param stance table|nil
--- @return nil
function M.draw_portrait_and_frame(rect, stance)
	M.draw_portrait(rect, stance)
	M.draw_frame(rect, stance)
end

return M
