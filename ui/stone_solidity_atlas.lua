--- Cached deterioration atlas from ``sprites/stones/stones.png``.
--- @module ui.stone_solidity_atlas

local atlas_params = require("objects.parameters.stone_solidity_atlas")
local sprites = require("ui.sprites")

local M = {}

local built = false
local image = false
local warned_quad = false
local quads = {
	white = {},
	black = {},
}

--- @param rect table
--- @param iw number
--- @param ih number
--- @return boolean
local function rect_fits_image(rect, iw, ih)
	if not rect or rect.w <= 0 or rect.h <= 0 then
		return false
	end
	return rect.x >= 0 and rect.y >= 0 and rect.x + rect.w <= iw + 0.5 and rect.y + rect.h <= ih + 0.5
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
		local wrect = atlas_params.frames.white[tier + 1]
		local brect = atlas_params.frames.black[tier + 1]
		if wrect and rect_fits_image(wrect, iw, ih) then
			make_quad("white", tier, wrect, iw, ih)
		elseif wrect and not warned_quad then
			warned_quad = true
			print(
				string.format(
					"[gobel] Solidity atlas quad out of bounds (image %dx%d); fix objects/parameters/stone_solidity_atlas.lua",
					iw,
					ih
				)
			)
		end
		if brect and rect_fits_image(brect, iw, ih) then
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
