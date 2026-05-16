--- Global UI fonts: **Pixel Operator** when ``fonts/PixelOperator.ttf`` is present, otherwise LÖVE default.
--- Call ``init`` once from ``love.load``, then ``apply_default`` (or ``set``) before ``print``/``printf``.
--- @module ui.fonts

local M = {}

local body
local body_small
local title
local large
local bold_cache = {}

local REGULAR_PATH = "fonts/PixelOperator.ttf"
local BOLD_PATH = "fonts/PixelOperator-Bold.ttf"

--- @param path string
--- @param px integer
--- @return love.graphics.Font|nil
local function load_ttf(path, px)
	if not love.filesystem.getInfo(path) then
		return nil
	end
	local ok, font = pcall(love.graphics.newFont, path, px)
	if ok and font then
		return font
	end
	return nil
end

--- Loads TTF from ``fonts/PixelOperator.ttf`` at multiple pixel sizes; falls back to ``love.graphics.newFont``.
--- @return nil
function M.init()
	local f16 = load_ttf(REGULAR_PATH, 16)
	local f12 = load_ttf(REGULAR_PATH, 12)
	local f20 = load_ttf(REGULAR_PATH, 20)
	local f36 = load_ttf(REGULAR_PATH, 36)
	if not f16 then
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

--- Bold variant of ``body`` or ``body_small`` (cached; ``fonts/PixelOperator-Bold.ttf``).
--- @param which string|nil  ``"body"`` | ``"body_small"``
--- @return love.graphics.Font
function M.get_bold(which)
	local key = which == "body_small" and "body_small" or "body"
	if bold_cache[key] then
		return bold_cache[key]
	end
	local px = key == "body_small" and 12 or 16
	local f = load_ttf(BOLD_PATH, px) or load_ttf(REGULAR_PATH, px) or love.graphics.newFont(px)
	bold_cache[key] = f
	return f
end

--- @param which string|nil
--- @return nil
function M.set_bold(which)
	love.graphics.setFont(M.get_bold(which))
end

local sized_cache = {}

--- Pixel Operator at arbitrary pixel height (cached). Falls back to default ``newFont(px)``.
--- @param px integer
--- @return love.graphics.Font
function M.get_pixel_operator(px)
	if sized_cache[px] then
		return sized_cache[px]
	end
	local f = load_ttf(REGULAR_PATH, px) or love.graphics.newFont(px)
	sized_cache[px] = f
	return f
end

return M
