--- Playing-card and stance art aspect: 2.5" × 3.5" (1024×1435 PNGs).
--- @module ui.card_geometry

local M = {}

M.WIDTH_TO_HEIGHT = 2.5 / 3.5

--- @param width number
--- @return number
function M.height_for_width(width)
	return width / M.WIDTH_TO_HEIGHT
end

--- @param height number
--- @return number
function M.width_for_height(height)
	return height * M.WIDTH_TO_HEIGHT
end

--- Largest 2.5×3.5 rect that fits inside ``max_w`` × ``max_h``.
--- @param max_w number
--- @param max_h number
--- @return number w
--- @return number h
function M.fit_inside(max_w, max_h)
	local w = max_w
	local h = M.height_for_width(w)
	if h > max_h then
		h = max_h
		w = M.width_for_height(h)
	end
	return w, h
end

--- Centered rect with 2.5×3.5 aspect inside ``bounds`` (`x`, `y`, `w`, `h`).
--- @param bounds table
--- @return table
function M.aspect_rect_in_bounds(bounds)
	local w, h = M.fit_inside(bounds.w, bounds.h)
	return {
		x = bounds.x + (bounds.w - w) * 0.5,
		y = bounds.y + (bounds.h - h) * 0.5,
		w = w,
		h = h,
	}
end

--- Uniform scale + position to draw a 1024×1435 (or matching) image into ``bounds`` without distortion.
--- Uses full bounds when image and bounds aspects match; otherwise ``contain``.
--- @param bounds table
--- @param image_w number
--- @param image_h number
--- @return number dx
--- @return number dy
--- @return number dw
--- @return number dh
--- @return number scale_x  multiplier for ``love.graphics.draw`` (dw / image_w)
--- @return number scale_y
function M.image_draw_dest(bounds, image_w, image_h)
	local inner = M.aspect_rect_in_bounds(bounds)
	local img_aspect = image_w / image_h
	local rect_aspect = inner.w / inner.h
	if math.abs(img_aspect - rect_aspect) < 0.02 then
		return inner.x, inner.y, inner.w, inner.h, inner.w / image_w, inner.h / image_h
	end
	local sx = inner.w / image_w
	local sy = inner.h / image_h
	local s = math.min(sx, sy)
	local dw = image_w * s
	local dh = image_h * s
	local dx = inner.x + (inner.w - dw) * 0.5
	local dy = inner.y + (inner.h - dh) * 0.5
	return dx, dy, dw, dh, dw / image_w, dh / image_h
end

--- Stretch asset to the full 2.5×3.5 inner rect (portrait + frame share width and height).
--- @param bounds table
--- @param image_w number
--- @param image_h number
--- @return number dx
--- @return number dy
--- @return number dw
--- @return number dh
--- @return number scale_x
--- @return number scale_y
function M.image_draw_dest_stretch(bounds, image_w, image_h)
	local inner = M.aspect_rect_in_bounds(bounds)
	return inner.x, inner.y, inner.w, inner.h, inner.w / image_w, inner.h / image_h
end

return M
