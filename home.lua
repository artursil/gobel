--- Home screen: game type selection and match mode selection.

local config = require("config")
local game_types = require("game_types.definitions")

local M = {}

--- Computes dropdown menu rect for game types.
--- @param window_w number
--- @param window_h number
--- @return table
local function layout_game_type_dropdown(window_w, window_h)
	local dw = math.min(380, window_w - 48)
	local dh = 60
	local dx = (window_w - dw) / 2
	local dy = window_h * 0.5 - dh * 0.5
	return { x = dx, y = dy, w = dw, h = dh }
end

--- Computes dropdown options list rects.
--- @param dropdown_rect table
--- @param num_options integer
--- @return table
local function layout_dropdown_options(dropdown_rect, num_options)
	local options = {}
	for i = 1, num_options do
		options[i] = {
			x = dropdown_rect.x,
			y = dropdown_rect.y + dropdown_rect.h + (i - 1) * 50,
			w = dropdown_rect.w,
			h = 48,
		}
	end
	return options
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
	local total_h = bh * 2 + gap
	local y0 = window_h * 0.5 - total_h * 0.5
	return {
		pvp = { x = x, y = y0, w = bw, h = bh },
		pvc = { x = x, y = y0 + (bh + gap), w = bw, h = bh },
	}
end

--- Hit test for game type selection menu.
--- @param px number
--- @param py number
--- @param window_w number
--- @param window_h number
--- @param dropdown_open boolean
--- @param selected_game_type string
--- @return string|nil
function M.hit_test_game_type(px, py, window_w, window_h, dropdown_open, selected_game_type)
	if dropdown_open then
		local dropdown = layout_game_type_dropdown(window_w, window_h)
		local game_types_list = game_types.get_all_types()
		local options = layout_dropdown_options(dropdown, #game_types_list)
		for i, option in ipairs(options) do
			if px >= option.x and px <= option.x + option.w and py >= option.y and py <= option.y + option.h then
				return "game_type:" .. game_types_list[i].id
			end
		end
		return "dropdown_close"
	end

	local dropdown = layout_game_type_dropdown(window_w, window_h)
	if px >= dropdown.x and px <= dropdown.x + dropdown.w and py >= dropdown.y and py <= dropdown.y + dropdown.h then
		return "dropdown_open"
	end
	return nil
end

--- Hit test for match mode selection menu.
--- @param px number
--- @param py number
--- @param window_w number
--- @param window_h number
--- @return string|nil
function M.hit_test_match(px, py, window_w, window_h)
	local L = layout_match_buttons(window_w, window_h)
	local names = { "pvp", "pvc" }
	for _, name in ipairs(names) do
		local rect = L[name]
		if px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h then
			return name
		end
	end
	return nil
end

--- Draws the game type selection menu.
--- @param window_w number
--- @param window_h number
--- @param dropdown_open boolean
--- @param selected_game_type string
function M.draw_game_type_menu(window_w, window_h, dropdown_open, selected_game_type)
	local lg = love.graphics
	lg.clear(config.COLOR_BOARD[1], config.COLOR_BOARD[2], config.COLOR_BOARD[3])
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	local title = "Go"
	local sub = "Select Game Type"
	lg.printf(title, 0, window_h * 0.22, window_w, "center")
	local f = lg.getFont()
	local title_h = f:getHeight()
	lg.printf(sub, 0, window_h * 0.22 + title_h + 8, window_w, "center")

	local btn_fill = { 0.35, 0.32, 0.28 }
	local btn_border = { 0.12, 0.1, 0.08 }

	local dropdown = layout_game_type_dropdown(window_w, window_h)
	lg.setColor(btn_fill[1], btn_fill[2], btn_fill[3])
	lg.rectangle("fill", dropdown.x, dropdown.y, dropdown.w, dropdown.h, 6, 6)
	lg.setColor(btn_border[1], btn_border[2], btn_border[3])
	lg.setLineWidth(2)
	lg.rectangle("line", dropdown.x, dropdown.y, dropdown.w, dropdown.h, 6, 6)

	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	local game_type_name = selected_game_type
	for _, gt in ipairs(game_types.get_all_types()) do
		if gt.id == selected_game_type then
			game_type_name = gt.name
			break
		end
	end
	lg.printf(game_type_name, dropdown.x + 12, dropdown.y + (dropdown.h - f:getHeight()) / 2, dropdown.w - 24, "left")

	if dropdown_open then
		local game_types_list = game_types.get_all_types()
		local options = layout_dropdown_options(dropdown, #game_types_list)
		for i, option in ipairs(options) do
			lg.setColor(btn_fill[1], btn_fill[2], btn_fill[3])
			lg.rectangle("fill", option.x, option.y, option.w, option.h, 4, 4)
			lg.setColor(btn_border[1], btn_border[2], btn_border[3])
			lg.setLineWidth(1)
			lg.rectangle("line", option.x, option.y, option.w, option.h, 4, 4)
			lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
			lg.printf(game_types_list[i].name, option.x + 12, option.y + (option.h - f:getHeight()) / 2, option.w - 24, "left")
		end
	end

	lg.printf("Esc quit", 0, window_h - 56, window_w, "center")
	lg.setColor(1, 1, 1, 1)
end

--- Draws the match mode selection menu.
--- @param window_w number
--- @param window_h number
--- @param selected_game_type string
function M.draw_match_menu(window_w, window_h, selected_game_type)
	local lg = love.graphics
	lg.clear(config.COLOR_BOARD[1], config.COLOR_BOARD[2], config.COLOR_BOARD[3])
	lg.setColor(config.COLOR_UI[1], config.COLOR_UI[2], config.COLOR_UI[3])
	local title = "Go"
	local sub = "Choose how to play"
	lg.printf(title, 0, window_h * 0.22, window_w, "center")
	local f = lg.getFont()
	local title_h = f:getHeight()
	lg.printf(sub, 0, window_h * 0.22 + title_h + 8, window_w, "center")

	local game_type_name = selected_game_type
	for _, gt in ipairs(game_types.get_all_types()) do
		if gt.id == selected_game_type then
			game_type_name = gt.name
			break
		end
	end
	lg.setColor(0.6, 0.6, 0.6)
	lg.printf("Mode: " .. game_type_name, 0, window_h * 0.22 + title_h + 32, window_w, "center")

	local btn_fill = { 0.35, 0.32, 0.28 }
	local btn_border = { 0.12, 0.1, 0.08 }

	local L = layout_match_buttons(window_w, window_h)
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
	lg.printf("Two players", L.pvp.x, y1, L.pvp.w, "center")
	lg.printf("vs random bot", L.pvc.x, y2, L.pvc.w, "center")
	lg.printf("Esc back  ·  click a mode", 0, window_h - 56, window_w, "center")
	lg.setColor(1, 1, 1, 1)
end

return M
