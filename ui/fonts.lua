--- Global UI fonts: **Pixel Operator** when ``fonts/PixelOperator.ttf`` is present, otherwise LÖVE default.
--- Call ``init`` once from ``love.load``, then ``apply_default`` (or ``set``) before ``print``/``printf``.
--- @module ui.fonts

local M = {}

local body
local body_small
local title
local large

--- Loads TTF from ``fonts/PixelOperator.ttf`` at multiple pixel sizes; falls back to ``love.graphics.newFont``.
--- @return nil
function M.init()
	local path = "fonts/PixelOperator.ttf"
	local info = love.filesystem.getInfo(path)
	local ok, f16, f12, f20, f36
	if info then
		ok, f16 = pcall(love.graphics.newFont, path, 16)
		if ok then
			f12 = love.graphics.newFont(path, 12)
			f20 = love.graphics.newFont(path, 20)
			f36 = love.graphics.newFont(path, 36)
		end
	end
	if not ok or not f16 then
		f16 = love.graphics.newFont(16)
		f12 = love.graphics.newFont(12)
		f20 = love.graphics.newFont(20)
		f36 = love.graphics.newFont(36)
	end
	body = f16
	body_small = f12
	title = f20
	large = f36
end

--- Sets the active font to the default body size.
--- @return nil
function M.apply_default()
	if body then
		love.graphics.setFont(body)
	end
end

--- @param which string  ``"body"`` | ``"body_small"`` | ``"title"`` | ``"large"``
--- @return love.graphics.Font
function M.get(which)
	if which == "body_small" then
		return body_small or body
	end
	if which == "title" then
		return title or body
	end
	if which == "large" then
		return large or body
	end
	return body
end

--- @param which string|nil  defaults to ``"body"``
--- @return nil
function M.set(which)
	local w = which or "body"
	love.graphics.setFont(M.get(w))
end

local sized_cache = {}

--- Pixel Operator at arbitrary pixel height (cached). Falls back to default ``newFont(px)``.
--- @param px integer
--- @return love.graphics.Font
function M.get_pixel_operator(px)
	if sized_cache[px] then
		return sized_cache[px]
	end
	local path = "fonts/PixelOperator.ttf"
	local f
	if love.filesystem.getInfo(path) then
		local ok, font = pcall(love.graphics.newFont, path, px)
		if ok and font then
			f = font
		end
	end
	if not f then
		f = love.graphics.newFont(px)
	end
	sized_cache[px] = f
	return f
end

return M
