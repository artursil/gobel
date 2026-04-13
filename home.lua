--- Home screen: mode selection and hit testing for menu buttons.

local config = require("config")

local M = {}

--- Computes centered button rectangles for the current window size.
--- @param window_w number
--- @param window_h number
--- @return table
local function layout_buttons(window_w, window_h)
	local bw = math.min(380, window_w - 48)
	local bh = 52
	local x = (window_w - bw) / 2
	local gap = 16
	local mid = window_h * 0.48
	return {
		pvp = { x = x, y = mid - bh - gap * 0.5, w = bw, h = bh },
		pvc = { x = x, y = mid + gap * 0.5, w = bw, h = bh },
	}
end

--- Returns which mode was hit, or nil.
--- @param px number
--- @param py number
--- @param window_w number
--- @param window_h number
--- @return string|nil
function M.hit_test(px, py, window_w, window_h)
	local L = layout_buttons(window_w, window_h)
	for name, rect in pairs(L) do
		if px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h then
			return name
		end
	end
	return nil
end

--- Draws title, subtitle, and two mode buttons.
--- @param window_w number
--- @param window_h number
function M.draw(window_w, window_h)
	local lg = love.graphics
	lg.clear(config.COLOR_BOARD[1], config.COLOR_BOARD[2], config.COLOR_BOARD[3])
	local L = layout_buttons(window_w, window_h)
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	local title = "Go"
	local sub = "Choose how to play"
	lg.printf(title, 0, window_h * 0.22, window_w, "center")
	local f = lg.getFont()
	local title_h = f:getHeight()
	lg.printf(sub, 0, window_h * 0.22 + title_h + 8, window_w, "center")
	local btn_fill = { 0.35, 0.32, 0.28 }
	local btn_border = { 0.12, 0.1, 0.08 }
	for _, key in ipairs({ "pvp", "pvc" }) do
		local r = L[key]
		lg.setColor(btn_fill[1], btn_fill[2], btn_fill[3])
		lg.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
		lg.setColor(btn_border[1], btn_border[2], btn_border[3])
		lg.setLineWidth(2)
		lg.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
	end
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	local y1 = L.pvp.y + (L.pvp.h - f:getHeight()) / 2
	local y2 = L.pvc.y + (L.pvc.h - f:getHeight()) / 2
	lg.printf("Two players (same device)", L.pvp.x, y1, L.pvp.w, "center")
	lg.printf("Player vs random bot", L.pvc.x, y2, L.pvc.w, "center")
	lg.printf("Esc quit  ·  click a mode", 0, window_h - 56, window_w, "center")
	lg.setColor(1, 1, 1, 1)
end

return M
