--- Home screen: mode selection and hit testing for menu buttons.

local config = require("config")

local M = {}

--- Computes centered button rectangles for the current window size.
--- @param window_w number
--- @param window_h number
--- @return table
local function layout_territory_buttons(window_w, window_h)
	local bw = math.min(440, window_w - 48)
	local bh = 56
	local x = (window_w - bw) / 2
	local gap = 16
	local total_h = bh * 2 + gap
	local y0 = window_h * 0.52 - total_h * 0.5
	return {
		regional = { x = x, y = y0, w = bw, h = bh },
		distance_only = { x = x, y = y0 + bh + gap, w = bw, h = bh },
	}
end

--- Computes centered match mode buttons for the current window size.
--- @param window_w number
--- @param window_h number
--- @return table
local function layout_match_buttons(window_w, window_h)
	local bw = math.min(380, window_w - 48)
	local bh = 52
	local x = (window_w - bw) / 2
	local gap = 12
	local total_h = bh * 4 + gap * 3
	local y0 = window_h * 0.5 - total_h * 0.5
	return {
		pvp = { x = x, y = y0, w = bw, h = bh },
		pvc = { x = x, y = y0 + (bh + gap), w = bw, h = bh },
		pvp_basic = { x = x, y = y0 + (bh + gap) * 2, w = bw, h = bh },
		pvc_basic = { x = x, y = y0 + (bh + gap) * 3, w = bw, h = bh },
	}
end

--- Returns which mode was hit, or nil.
--- @param px number
--- @param py number
--- @param window_w number
--- @param window_h number
--- @param menu_step string
--- @return string|nil
function M.hit_test(px, py, window_w, window_h, menu_step)
	local L
	local names
	if menu_step == "territory" then
		L = layout_territory_buttons(window_w, window_h)
		names = { "regional", "distance_only" }
	else
		L = layout_match_buttons(window_w, window_h)
		names = { "pvp", "pvc", "pvp_basic", "pvc_basic" }
	end
	for _, name in ipairs(names) do
		local rect = L[name]
		if px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h then
			return name
		end
	end
	return nil
end

--- Draws title, subtitle, and mode buttons.
--- @param window_w number
--- @param window_h number
--- @param menu_step string
--- @param territory_mode string|nil
function M.draw(window_w, window_h, menu_step, territory_mode)
	local lg = love.graphics
	lg.clear(config.COLOR_BOARD[1], config.COLOR_BOARD[2], config.COLOR_BOARD[3])
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	local title = "Go"
	local sub = menu_step == "territory" and "Choose territory algorithm" or "Choose how to play"
	lg.printf(title, 0, window_h * 0.22, window_w, "center")
	local f = lg.getFont()
	local title_h = f:getHeight()
	lg.printf(sub, 0, window_h * 0.22 + title_h + 8, window_w, "center")
	local btn_fill = { 0.35, 0.32, 0.28 }
	local btn_border = { 0.12, 0.1, 0.08 }
	local selected_fill = { 0.48, 0.43, 0.36 }
	if menu_step == "territory" then
		local L = layout_territory_buttons(window_w, window_h)
		for _, key in ipairs({ "regional", "distance_only" }) do
			local r = L[key]
			local fill = btn_fill
			if territory_mode == key then
				fill = selected_fill
			end
			lg.setColor(fill[1], fill[2], fill[3])
			lg.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
			lg.setColor(btn_border[1], btn_border[2], btn_border[3])
			lg.setLineWidth(2)
			lg.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)
		end
		lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
		local y1 = L.regional.y + (L.regional.h - f:getHeight()) / 2
		local y2 = L.distance_only.y + (L.distance_only.h - f:getHeight()) / 2
		lg.printf("Regional + enclosure (current)", L.regional.x, y1, L.regional.w, "center")
		lg.printf("Manhattan distance only", L.distance_only.x, y2, L.distance_only.w, "center")
		lg.printf("Esc quit  ·  click a ruleset", 0, window_h - 56, window_w, "center")
		lg.setColor(1, 1, 1, 1)
		return
	end
	local L = layout_match_buttons(window_w, window_h)
	for _, key in ipairs({ "pvp", "pvc", "pvp_basic", "pvc_basic" }) do
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
	local y3 = L.pvp_basic.y + (L.pvp_basic.h - f:getHeight()) / 2
	local y4 = L.pvc_basic.y + (L.pvc_basic.h - f:getHeight()) / 2
	lg.printf("Standard: two players", L.pvp.x, y1, L.pvp.w, "center")
	lg.printf("Standard: vs random bot", L.pvc.x, y2, L.pvc.w, "center")
	lg.printf("Basic stones only: two players", L.pvp_basic.x, y3, L.pvp_basic.w, "center")
	lg.printf("Basic stones only: vs bot", L.pvc_basic.x, y4, L.pvc_basic.w, "center")
	local ruleset_name = territory_mode == "distance_only" and "Manhattan distance only" or "Regional + enclosure"
	lg.printf("Scoring: " .. ruleset_name, 0, window_h - 84, window_w, "center")
	lg.printf("Esc back  ·  click a mode", 0, window_h - 56, window_w, "center")
	lg.setColor(1, 1, 1, 1)
end

return M
