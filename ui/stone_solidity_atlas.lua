--- Cached deterioration atlas from ``sprites/stones/stones.png``.
--- @module ui.stone_solidity_atlas

local atlas_params = require("objects.parameters.stone_solidity_atlas")
local sprites = require("ui.sprites")

local M = {}

local built = false
local image = false
local quads = {
	white = {},
	black = {},
}

--- @return boolean
local function manual_frames_configured()
	local frames = atlas_params.frames
	if not frames or not frames.white or not frames.black then
		return false
	end
	return #frames.white >= 4 and #frames.black >= 4
end

--- @param iw number
--- @param ih number
--- @return number
local function default_inset(iw, ih)
	local cols = atlas_params.cols or 4
	local rows = 2
	local cell = math.min(iw / cols, ih / rows)
	return math.max(2, math.floor(cell * 0.02))
end

--- @param rect table
--- @param iw number
--- @param ih number
--- @return boolean
function M.rect_fits_image(rect, iw, ih)
	if not rect or rect.w <= 0 or rect.h <= 0 then
		return false
	end
	return rect.x >= 0 and rect.y >= 0 and rect.x + rect.w <= iw + 0.5 and rect.y + rect.h <= ih + 0.5
end

--- One cell in the 2×4 grid (tier = column index).
--- @param iw number
--- @param ih number
--- @param row integer 0 = top row, 1 = bottom row
--- @param col integer 0..3
--- @return table
function M.grid_frame_rect(iw, ih, row, col)
	local cols = atlas_params.cols or 4
	local inset = atlas_params.inset or default_inset(iw, ih)
	local cell_w = iw / cols
	local cell_h = ih / 2
	return {
		x = col * cell_w + inset,
		y = row * cell_h + inset,
		w = cell_w - 2 * inset,
		h = cell_h - 2 * inset,
	}
end

--- Rect used for a tier: manual from params when set and in-bounds, else grid cell.
--- @param owner_side string ``"black"`` | ``"white"``
--- @param tier integer 0..3
--- @param iw number
--- @param ih number
--- @return table
function M.frame_rect(owner_side, tier, iw, ih)
	local row_key = owner_side == "white" and "white" or "black"
	if manual_frames_configured() then
		local manual = atlas_params.frames[row_key][tier + 1]
		if manual and M.rect_fits_image(manual, iw, ih) then
			return manual
		end
	end
	local row = row_key == "white" and (atlas_params.row_white or 0) or (atlas_params.row_black or 1)
	return M.grid_frame_rect(iw, ih, row, tier)
end

--- @param row_key string
--- @param tier integer
--- @param rect table
--- @param iw number
--- @param ih number
--- @return love.graphics.Quad|nil
local function make_quad(row_key, tier, rect, iw, ih)
	if not love or not love.graphics or not love.graphics.newQuad then
		return nil
	end
	local ok, quad = pcall(love.graphics.newQuad, rect.x, rect.y, rect.w, rect.h, iw, ih)
	if ok then
		quads[row_key][tier] = quad
		return quad
	end
	return nil
end

--- @return nil
local function ensure_built()
	if built then
		return
	end
	built = true
	local img = sprites.get_image(atlas_params.path)
	if not img or img == false then
		image = false
		return
	end
	image = img
	local iw = img:getWidth()
	local ih = img:getHeight()
	for tier = 0, 3 do
		local wrect = M.frame_rect("white", tier, iw, ih)
		local brect = M.frame_rect("black", tier, iw, ih)
		if M.rect_fits_image(wrect, iw, ih) then
			make_quad("white", tier, wrect, iw, ih)
		end
		if M.rect_fits_image(brect, iw, ih) then
			make_quad("black", tier, brect, iw, ih)
		end
	end
end

--- @return boolean
function M.is_available()
	ensure_built()
	return image ~= false and next(quads.white) ~= nil
end

--- @param owner_side string ``"black"`` | ``"white"``
--- @param tier integer 0..3
--- @return love.graphics.Image|nil
--- @return love.graphics.Quad|nil
function M.get_frame(owner_side, tier)
	ensure_built()
	if not image then
		return nil, nil
	end
	local row_key = owner_side == "white" and "white" or "black"
	local quad = quads[row_key][tier]
	if not quad then
		return nil, nil
	end
	return image, quad
end

--- Clears cached atlas (tests only).
--- @return nil
function M.reset_for_tests()
	built = false
	image = false
	quads.white = {}
	quads.black = {}
end

return M
